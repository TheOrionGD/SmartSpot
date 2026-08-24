const crypto = require('node:crypto');
const path = require('node:path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
require('dotenv').config();
const db = require('./db');

const app = express();
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';
const isProduction = process.env.NODE_ENV === 'production';

if (isProduction && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be configured in production');
}

const jwtSecret = process.env.JWT_SECRET || 'development-only-change-me';
const brevoApiKey = process.env.BREVO_API_KEY;
const mailFrom = process.env.MAIL_FROM;
const mailFromName = process.env.MAIL_FROM_NAME || 'SmartSpot';

const now = () => new Date().toISOString();
const id = () => crypto.randomUUID();
const publicUser = (user) => ({
  id: user.id,
  name: user.name,
  email: user.email,
  createdAt: user.createdAt,
});
const signToken = (user) => jwt.sign({ sub: user.id }, jwtSecret, { expiresIn: '30d' });

async function sendPasswordChangedEmail(email, name) {
  if (!brevoApiKey || !mailFrom) return;
  try {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        accept: 'application/json',
        'api-key': brevoApiKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sender: { name: mailFromName, email: mailFrom },
        to: [{ email, name }],
        subject: 'Your SmartSpot password was changed',
        textContent:
          'Your SmartSpot password was changed successfully. If you did not do this, contact support immediately.',
      }),
    });
    if (!response.ok) {
      console.warn(`Brevo email failed with status ${response.status}`);
    }
  } catch (error) {
    console.warn(`Brevo email failed: ${error.message}`);
  }
}

app.set('trust proxy', isProduction ? 1 : 0);
app.use(helmet({ contentSecurityPolicy: false }));
app.use(
  cors({
    origin: !process.env.CORS_ORIGIN || process.env.CORS_ORIGIN.trim() === '*'
      ? '*'
      : process.env.CORS_ORIGIN.split(',').map((origin) => origin.trim()),
  })
);

app.use(express.static(path.join(__dirname, '../public')));

// Rate limiter for API routes
app.use(
  '/api',
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 500,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
  })
);

app.use(express.json({ limit: '2mb' }));

// Auth Middleware
function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  try {
    req.user = jwt.verify(token, jwtSecret);
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// ---------------------------------------------------------------------------
// Root Landing, Reset Password Web UI & Health check
// ---------------------------------------------------------------------------
app.get('/', (_req, res) =>
  res.json({
    status: 'online',
    message: 'Welcome to SmartSpot Location Reminders REST API',
    health: '/health',
    resetPasswordUI: '/reset-password',
    documentation: 'https://github.com/TheOrionGD/SmartSpot',
    timestamp: now(),
  })
);

app.get('/health', (_req, res) =>
  res.json({ ok: true, service: 'smartspot-backend', timestamp: now() })
);

app.get(['/reset-password', '/forgot-password'], (_req, res) => {
  res.sendFile(path.join(__dirname, '../public/reset-password.html'));
});

// ---------------------------------------------------------------------------
// Authentication & User Management Routes
// ---------------------------------------------------------------------------
app.post('/api/auth/register', (req, res) => {
  const { name, email, password, securityQuestion, securityAnswer } = req.body || {};
  if (
    !name?.trim() ||
    !email?.trim() ||
    typeof password !== 'string' ||
    password.length < 6 ||
    !securityQuestion?.trim() ||
    typeof securityAnswer !== 'string' ||
    securityAnswer.trim().length < 2
  ) {
    return res.status(400).json({
      error: 'Name, email, password (min 6 chars), security question, and answer are required',
    });
  }

  const normalizedEmail = email.trim().toLowerCase();
  if (db.find('users', (user) => user.email === normalizedEmail)) {
    return res.status(409).json({ error: 'Email is already registered' });
  }

  const user = {
    id: id(),
    name: name.trim(),
    email: normalizedEmail,
    passwordHash: bcrypt.hashSync(password, 12),
    securityQuestion: securityQuestion.trim(),
    securityAnswerHash: bcrypt.hashSync(securityAnswer.trim().toLowerCase(), 12),
    createdAt: now(),
  };

  db.insert('users', user);
  res.status(201).json({ user: publicUser(user), token: signToken(user) });
});

app.post('/api/auth/login', (req, res) => {
  const email = req.body?.email?.trim().toLowerCase();
  const password = req.body?.password;

  const user = db.find('users', (candidate) => candidate.email === email);
  if (!user || typeof password !== 'string' || !bcrypt.compareSync(password, user.passwordHash)) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  res.json({ user: publicUser(user), token: signToken(user) });
});

app.post('/api/auth/security-question', (req, res) => {
  const email = req.body?.email?.trim().toLowerCase();
  const user = db.find('users', (candidate) => candidate.email === email);
  if (!user || !user.securityQuestion) {
    return res.status(404).json({ error: 'No security question is available for this account' });
  }
  res.json({ securityQuestion: user.securityQuestion });
});

app.post('/api/auth/reset-password', async (req, res) => {
  const email = req.body?.email?.trim().toLowerCase();
  const securityAnswer = req.body?.securityAnswer;
  const newPassword = req.body?.newPassword;

  const user = db.find('users', (candidate) => candidate.email === email);
  if (
    !user ||
    !user.securityAnswerHash ||
    typeof securityAnswer !== 'string' ||
    !bcrypt.compareSync(securityAnswer.trim().toLowerCase(), user.securityAnswerHash)
  ) {
    return res.status(401).json({ error: 'Incorrect email or security answer' });
  }

  if (typeof newPassword !== 'string' || newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters' });
  }

  db.update('users', (candidate) => candidate.id === user.id, {
    passwordHash: bcrypt.hashSync(newPassword, 12),
  });

  await sendPasswordChangedEmail(user.email, user.name);
  res.json({ message: 'Password reset successfully' });
});

app.get('/api/auth/me', auth, (req, res) => {
  const user = db.find('users', (candidate) => candidate.id === req.user.sub);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ user: publicUser(user) });
});

app.put('/api/auth/profile', auth, (req, res) => {
  const user = db.find('users', (candidate) => candidate.id === req.user.sub);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const { name, email } = req.body || {};
  const updates = {};

  if (name && typeof name === 'string' && name.trim()) {
    updates.name = name.trim();
  }

  if (email && typeof email === 'string' && email.trim()) {
    const normalizedEmail = email.trim().toLowerCase();
    const existing = db.find('users', (u) => u.email === normalizedEmail && u.id !== user.id);
    if (existing) {
      return res.status(409).json({ error: 'Email is already taken by another account' });
    }
    updates.email = normalizedEmail;
  }

  const updatedUser = db.update('users', (candidate) => candidate.id === user.id, updates);
  res.json({ user: publicUser(updatedUser) });
});

app.post('/api/auth/change-password', auth, async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  const user = db.find('users', (candidate) => candidate.id === req.user.sub);
  if (!user) return res.status(404).json({ error: 'User not found' });

  if (typeof currentPassword !== 'string' || !bcrypt.compareSync(currentPassword, user.passwordHash)) {
    return res.status(401).json({ error: 'Current password is incorrect' });
  }

  if (typeof newPassword !== 'string' || newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters long' });
  }

  db.update('users', (candidate) => candidate.id === user.id, {
    passwordHash: bcrypt.hashSync(newPassword, 12),
  });

  await sendPasswordChangedEmail(user.email, user.name);
  res.json({ message: 'Password changed successfully' });
});

// ---------------------------------------------------------------------------
// Reminders API Routes
// ---------------------------------------------------------------------------
app.get('/api/reminders', auth, (req, res) => {
  const { category, isCompleted, isArchived, search } = req.query;

  let items = db.all('reminders', (item) => item.userId === req.user.sub);

  if (category) {
    items = items.filter((item) => item.payload?.category === category);
  }
  if (isCompleted !== undefined) {
    const wantCompleted = isCompleted === 'true' || isCompleted === '1';
    items = items.filter((item) => Boolean(item.payload?.isCompleted) === wantCompleted);
  }
  if (isArchived !== undefined) {
    const wantArchived = isArchived === 'true' || isArchived === '1';
    items = items.filter((item) => Boolean(item.payload?.isArchived) === wantArchived);
  }
  if (search && typeof search === 'string') {
    const term = search.toLowerCase();
    items = items.filter((item) => {
      const p = item.payload || {};
      return (
        p.title?.toLowerCase().includes(term) ||
        p.description?.toLowerCase().includes(term) ||
        p.locationName?.toLowerCase().includes(term)
      );
    });
  }

  res.json(items.map((item) => item.payload));
});

app.post('/api/reminders', auth, (req, res) => {
  const payload = req.body;
  if (!payload?.title || typeof payload.latitude !== 'number' || typeof payload.longitude !== 'number') {
    return res.status(400).json({ error: 'title, latitude, and longitude are required' });
  }

  const reminderId = payload.id || id();
  const reminderPayload = {
    ...payload,
    id: reminderId,
    createdAt: payload.createdAt || now(),
  };

  db.upsert(
    'reminders',
    (item) => item.id === reminderId && item.userId === req.user.sub,
    {
      id: reminderId,
      userId: req.user.sub,
      payload: reminderPayload,
      createdAt: reminderPayload.createdAt,
      updatedAt: now(),
    }
  );

  res.status(201).json(reminderPayload);
});

app.get('/api/reminders/:id', auth, (req, res) => {
  const record = db.find(
    'reminders',
    (item) => item.id === req.params.id && item.userId === req.user.sub
  );
  if (!record) return res.status(404).json({ error: 'Reminder not found' });
  res.json(record.payload);
});

app.put('/api/reminders/:id', auth, (req, res) => {
  const record = db.find(
    'reminders',
    (item) => item.id === req.params.id && item.userId === req.user.sub
  );
  if (!record) return res.status(404).json({ error: 'Reminder not found' });

  const updatedPayload = {
    ...record.payload,
    ...req.body,
    id: record.id,
    updatedAt: now(),
  };

  record.payload = updatedPayload;
  record.updatedAt = now();
  db.update('reminders', (item) => item.id === record.id && item.userId === req.user.sub, record);

  res.json(updatedPayload);
});

app.delete('/api/reminders/:id', auth, (req, res) => {
  const removed = db.remove(
    'reminders',
    (item) => item.id === req.params.id && item.userId === req.user.sub
  );
  if (!removed) return res.status(404).json({ error: 'Reminder not found' });
  res.status(204).end();
});

app.patch('/api/reminders/:id/complete', auth, (req, res) => {
  const record = db.find(
    'reminders',
    (item) => item.id === req.params.id && item.userId === req.user.sub
  );
  if (!record) return res.status(404).json({ error: 'Reminder not found' });

  const isCompleted = req.body?.isCompleted !== undefined ? Boolean(req.body.isCompleted) : !record.payload.isCompleted;

  record.payload = {
    ...record.payload,
    isCompleted,
    lastCompletedAt: isCompleted ? now() : record.payload.lastCompletedAt,
    updatedAt: now(),
  };
  record.updatedAt = now();
  db.update('reminders', (item) => item.id === record.id && item.userId === req.user.sub, record);

  res.json(record.payload);
});

app.patch('/api/reminders/:id/archive', auth, (req, res) => {
  const record = db.find(
    'reminders',
    (item) => item.id === req.params.id && item.userId === req.user.sub
  );
  if (!record) return res.status(404).json({ error: 'Reminder not found' });

  const isArchived = req.body?.isArchived !== undefined ? Boolean(req.body.isArchived) : !record.payload.isArchived;

  record.payload = {
    ...record.payload,
    isArchived,
    updatedAt: now(),
  };
  record.updatedAt = now();
  db.update('reminders', (item) => item.id === record.id && item.userId === req.user.sub, record);

  res.json(record.payload);
});

app.post('/api/reminders/sync', auth, (req, res) => {
  const clientReminders = Array.isArray(req.body?.reminders) ? req.body.reminders : [];

  for (const reminder of clientReminders) {
    if (!reminder.id || !reminder.title) continue;
    db.upsert(
      'reminders',
      (item) => item.id === reminder.id && item.userId === req.user.sub,
      {
        id: reminder.id,
        userId: req.user.sub,
        payload: reminder,
        createdAt: reminder.createdAt || now(),
        updatedAt: now(),
      }
    );
  }

  const allUserReminders = db
    .all('reminders', (item) => item.userId === req.user.sub)
    .map((item) => item.payload);

  res.json({ synced: clientReminders.length, reminders: allUserReminders });
});

// ---------------------------------------------------------------------------
// Favorites API Routes
// ---------------------------------------------------------------------------
app.get('/api/favorites', auth, (req, res) => {
  res.json(db.all('favorites', (item) => item.userId === req.user.sub).map((item) => item.payload));
});

app.post('/api/favorites', auth, (req, res) => {
  const favorite = { ...req.body, id: req.body?.id || id() };
  if (!favorite.label || typeof favorite.latitude !== 'number' || typeof favorite.longitude !== 'number') {
    return res.status(400).json({ error: 'label, latitude, and longitude are required' });
  }

  db.remove('favorites', (item) => item.id === favorite.id && item.userId === req.user.sub);
  db.insert('favorites', { id: favorite.id, userId: req.user.sub, payload: favorite, createdAt: now() });
  res.status(201).json(favorite);
});

app.put('/api/favorites/:id', auth, (req, res) => {
  const record = db.find(
    'favorites',
    (item) => item.id === req.params.id && item.userId === req.user.sub
  );
  if (!record) return res.status(404).json({ error: 'Favorite not found' });

  const updatedPayload = { ...record.payload, ...req.body, id: record.id };
  record.payload = updatedPayload;
  db.update('favorites', (item) => item.id === record.id && item.userId === req.user.sub, record);

  res.json(updatedPayload);
});

app.delete('/api/favorites/:id', auth, (req, res) => {
  if (!db.remove('favorites', (item) => item.id === req.params.id && item.userId === req.user.sub)) {
    return res.status(404).json({ error: 'Favorite not found' });
  }
  res.status(204).end();
});

// ---------------------------------------------------------------------------
// Family / Shared Groups API Routes
// ---------------------------------------------------------------------------
function buildGroupResponse(group) {
  const currentUser = db.find('users', (u) => u.id === group.ownerId);
  const ownerName = currentUser ? currentUser.name : 'Owner';

  const memberRecords = db.all('groupMembers', (member) => member.groupId === group.id);
  const memberNamesSet = new Set();

  for (const m of memberRecords) {
    if (m.memberName) {
      memberNamesSet.add(m.memberName);
    } else if (m.userId) {
      const u = db.find('users', (user) => user.id === m.userId);
      if (u?.name) memberNamesSet.add(u.name);
    }
  }

  return {
    ...group,
    ownerName,
    memberNames: Array.from(memberNamesSet),
  };
}

app.get('/api/groups', auth, (req, res) => {
  const userGroups = db.all(
    'groups',
    (group) =>
      group.ownerId === req.user.sub ||
      db.find('groupMembers', (member) => member.groupId === group.id && member.userId === req.user.sub)
  );

  res.json(userGroups.map(buildGroupResponse));
});

app.post('/api/groups', auth, (req, res) => {
  if (!req.body?.name?.trim()) {
    return res.status(400).json({ error: 'Group name is required' });
  }

  let inviteCode;
  do {
    inviteCode = crypto.randomBytes(3).toString('hex').toUpperCase();
  } while (db.find('groups', (group) => group.inviteCode === inviteCode));

  const group = {
    id: id(),
    ownerId: req.user.sub,
    name: req.body.name.trim(),
    inviteCode,
    createdAt: now(),
  };

  db.insert('groups', group);
  const user = db.find('users', (u) => u.id === req.user.sub);
  db.insert('groupMembers', {
    groupId: group.id,
    userId: req.user.sub,
    memberName: user?.name || 'Owner',
    joinedAt: group.createdAt,
  });

  res.status(201).json(buildGroupResponse(group));
});

app.put('/api/groups/:id', auth, (req, res) => {
  const group = db.find('groups', (g) => g.id === req.params.id && g.ownerId === req.user.sub);
  if (!group) {
    return res.status(404).json({ error: 'Group not found or you are not the owner' });
  }

  if (!req.body?.name?.trim()) {
    return res.status(400).json({ error: 'Group name is required' });
  }

  group.name = req.body.name.trim();
  db.update('groups', (g) => g.id === group.id, group);

  res.json(buildGroupResponse(group));
});

app.delete('/api/groups/:id', auth, (req, res) => {
  const group = db.find('groups', (g) => g.id === req.params.id);
  if (!group) return res.status(404).json({ error: 'Group not found' });

  if (group.ownerId === req.user.sub) {
    // Delete entire group and its members
    db.remove('groups', (g) => g.id === group.id);
    db.remove('groupMembers', (m) => m.groupId === group.id);
    return res.status(204).end();
  } else {
    // Leave group
    const removed = db.remove(
      'groupMembers',
      (m) => m.groupId === group.id && m.userId === req.user.sub
    );
    if (!removed) return res.status(404).json({ error: 'You are not a member of this group' });
    return res.status(204).end();
  }
});

app.post('/api/groups/join', auth, (req, res) => {
  const code = req.body?.inviteCode?.trim().toUpperCase();
  if (!code) return res.status(400).json({ error: 'Invite code is required' });

  const group = db.find('groups', (candidate) => candidate.inviteCode === code);
  if (!group) return res.status(404).json({ error: 'Invite code not found' });

  const existing = db.find(
    'groupMembers',
    (member) => member.groupId === group.id && member.userId === req.user.sub
  );

  if (!existing) {
    const user = db.find('users', (u) => u.id === req.user.sub);
    db.insert('groupMembers', {
      groupId: group.id,
      userId: req.user.sub,
      memberName: user?.name,
      joinedAt: now(),
    });
  }

  res.json(buildGroupResponse(group));
});

app.post('/api/groups/:id/members', auth, (req, res) => {
  const memberName = req.body?.memberName?.trim();
  if (!memberName) return res.status(400).json({ error: 'Member name is required' });

  const group = db.find('groups', (g) => g.id === req.params.id);
  if (!group) return res.status(404).json({ error: 'Group not found' });

  const isMember =
    group.ownerId === req.user.sub ||
    db.find('groupMembers', (m) => m.groupId === group.id && m.userId === req.user.sub);
  if (!isMember) return res.status(403).json({ error: 'Not authorized to add members to this group' });

  db.insert('groupMembers', {
    groupId: group.id,
    memberName,
    joinedAt: now(),
  });

  res.status(201).json(buildGroupResponse(group));
});

app.delete('/api/groups/:id/members/:memberName', auth, (req, res) => {
  const group = db.find('groups', (g) => g.id === req.params.id);
  if (!group) return res.status(404).json({ error: 'Group not found' });

  if (group.ownerId !== req.user.sub) {
    return res.status(403).json({ error: 'Only group owner can remove members' });
  }

  const targetName = decodeURIComponent(req.params.memberName);
  const removed = db.remove(
    'groupMembers',
    (m) => m.groupId === group.id && m.memberName?.toLowerCase() === targetName.toLowerCase()
  );

  if (!removed) return res.status(404).json({ error: 'Member not found in group' });
  res.status(204).end();
});

// ---------------------------------------------------------------------------
// Location Visits & Predictive Intelligence API Routes
// ---------------------------------------------------------------------------
app.get('/api/visits', auth, (req, res) => {
  const limit = Math.min(Number(req.query.limit || 100), 500);
  const visits = db
    .all('locationVisits', (item) => item.userId === req.user.sub)
    .slice(-limit)
    .map((item) => item.payload);

  res.json(visits);
});

app.post('/api/visits', auth, (req, res) => {
  const { latitude, longitude, locationName, category, timestamp } = req.body || {};
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    return res.status(400).json({ error: 'latitude and longitude are required numbers' });
  }

  const visitPayload = {
    id: req.body.id || id(),
    latitude,
    longitude,
    locationName: locationName || null,
    category: category || null,
    timestamp: timestamp || now(),
  };

  db.insert('locationVisits', {
    id: visitPayload.id,
    userId: req.user.sub,
    payload: visitPayload,
    createdAt: now(),
  });

  res.status(201).json(visitPayload);
});

// ---------------------------------------------------------------------------
// Analytics & Statistics API Routes
// ---------------------------------------------------------------------------
app.get('/api/analytics/statistics', auth, (req, res) => {
  const userReminders = db
    .all('reminders', (item) => item.userId === req.user.sub)
    .map((item) => item.payload || {});

  const activeReminders = userReminders.filter((r) => !r.isArchived);
  const completed = activeReminders.filter((r) => r.isCompleted).length;
  const pending = activeReminders.filter((r) => !r.isCompleted).length;
  const total = activeReminders.length;

  const categoryCounts = {};
  let totalMissed = 0;

  for (const reminder of activeReminders) {
    const cat = reminder.category || 'other';
    categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
    totalMissed += Number(reminder.missedCount || 0);
  }

  res.json({
    total,
    completed,
    pending,
    archived: userReminders.filter((r) => r.isArchived).length,
    totalMissed,
    categoryCounts,
  });
});

// Global error handler
app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: 'Internal server error' });
});

const server = app.listen(port, host, () =>
  console.log(`SmartSpot backend listening on ${host}:${port}`)
);

function shutdown(signal) {
  console.log(`${signal} received; shutting down`);
  server.close(() => process.exit(0));
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = app;
