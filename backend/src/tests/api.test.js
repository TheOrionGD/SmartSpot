const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

// Set test environment before requiring server/db
process.env.NODE_ENV = 'test';
process.env.PORT = '3099';
process.env.DB_FILE = './data/test_smartspot.json';

const db = require('../db');

// Start server
const app = require('../server');

const BASE_URL = 'http://127.0.0.1:3099';

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const reqOptions = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: options.method || 'GET',
      headers: options.headers || {},
    };

    const req = http.request(reqOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        let json = null;
        try {
          if (body) json = JSON.parse(body);
        } catch (_) {}
        resolve({ status: res.statusCode, headers: res.headers, body: json, rawBody: body });
      });
    });

    req.on('error', reject);

    if (options.body) {
      const payload = typeof options.body === 'string' ? options.body : JSON.stringify(options.body);
      req.setHeader('Content-Type', 'application/json');
      req.setHeader('Content-Length', Buffer.byteLength(payload));
      req.write(payload);
    }

    req.end();
  });
}

test('SmartSpot Backend End-to-End API Test Suite', async (t) => {
  // Clean DB before tests
  db.reset();

  let token = null;
  let userId = null;
  let reminderId = null;
  let favoriteId = null;
  let groupId = null;
  let inviteCode = null;

  await t.test('GET / - returns landing info', async () => {
    const res = await request('/');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'online');
    assert.equal(res.body.health, '/health');
  });

  await t.test('GET /health - returns ok', async () => {
    const res = await request('/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.service, 'smartspot-backend');
  });

  await t.test('POST /api/auth/register - registers new user', async () => {
    const res = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Test Student',
        email: 'student@example.com',
        password: 'Password123',
        securityQuestion: 'Favorite color?',
        securityAnswer: 'Blue',
      },
    });

    assert.equal(res.status, 201);
    assert.ok(res.body.token);
    assert.equal(res.body.user.name, 'Test Student');
    assert.equal(res.body.user.email, 'student@example.com');

    token = res.body.token;
    userId = res.body.user.id;
  });

  await t.test('POST /api/auth/login - authenticates user', async () => {
    const res = await request('/api/auth/login', {
      method: 'POST',
      body: {
        email: 'student@example.com',
        password: 'Password123',
      },
    });

    assert.equal(res.status, 200);
    assert.ok(res.body.token);
    assert.equal(res.body.user.id, userId);
  });

  await t.test('POST /api/auth/security-question - retrieves security question', async () => {
    const res = await request('/api/auth/security-question', {
      method: 'POST',
      body: { email: 'student@example.com' },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.securityQuestion, 'Favorite color?');
  });

  await t.test('GET /api/auth/me - gets profile with token', async () => {
    const res = await request('/api/auth/me', {
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.user.email, 'student@example.com');
  });

  await t.test('PUT /api/auth/profile - updates user full profile', async () => {
    const res = await request('/api/auth/profile', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        name: 'Updated Student',
        phone: '+1 555-0199',
        bio: 'CS Student & Tech Enthusiast',
        avatarUrl: 'person_rounded',
        securityQuestion: 'Updated Security Question?',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.user.name, 'Updated Student');
    assert.equal(res.body.user.phone, '+1 555-0199');
    assert.equal(res.body.user.bio, 'CS Student & Tech Enthusiast');
    assert.equal(res.body.user.avatarUrl, 'person_rounded');
    assert.equal(res.body.user.securityQuestion, 'Updated Security Question?');
  });

  await t.test('POST /api/reminders - creates location reminder', async () => {
    const res = await request('/api/reminders', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        title: 'Buy Textbooks',
        description: 'Pick up CS lab notebook',
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Campus Bookstore',
        category: 'college',
        priority: 'high',
        radius: 150,
      },
    });

    assert.equal(res.status, 201);
    assert.equal(res.body.title, 'Buy Textbooks');
    assert.ok(res.body.id);
    reminderId = res.body.id;
  });

  await t.test('GET /api/reminders - lists user reminders', async () => {
    const res = await request('/api/reminders', {
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.length, 1);
    assert.equal(res.body[0].title, 'Buy Textbooks');
  });

  await t.test('GET /api/reminders/:id - gets reminder by ID', async () => {
    const res = await request(`/api/reminders/${reminderId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.id, reminderId);
  });

  await t.test('PUT /api/reminders/:id - updates reminder', async () => {
    const res = await request(`/api/reminders/${reminderId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}` },
      body: { title: 'Buy Advanced CS Textbooks', radius: 200 },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.title, 'Buy Advanced CS Textbooks');
    assert.equal(res.body.radius, 200);
  });

  await t.test('PATCH /api/reminders/:id/complete - toggles completion status', async () => {
    const res = await request(`/api/reminders/${reminderId}/complete`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}` },
      body: { isCompleted: true },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.isCompleted, true);
    assert.ok(res.body.lastCompletedAt);
  });

  await t.test('PATCH /api/reminders/:id/archive - archives reminder', async () => {
    const res = await request(`/api/reminders/${reminderId}/archive`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}` },
      body: { isArchived: true },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.isArchived, true);
  });

  await t.test('POST /api/reminders/sync - bulk syncs reminders', async () => {
    const res = await request('/api/reminders/sync', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        reminders: [
          {
            id: 'synced-1',
            title: 'Library Return',
            latitude: 12.9,
            longitude: 77.5,
            category: 'college',
            isCompleted: false,
          },
        ],
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.synced, 1);
    assert.ok(res.body.reminders.length >= 2);
  });

  await t.test('DELETE /api/reminders/:id - deletes reminder', async () => {
    const res = await request(`/api/reminders/${reminderId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 204);
  });

  await t.test('POST /api/favorites - creates favorite place', async () => {
    const res = await request('/api/favorites', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        label: 'Main Library',
        latitude: 12.972,
        longitude: 77.595,
        address: 'Block A, Campus',
        icon: '📚',
      },
    });

    assert.equal(res.status, 201);
    assert.equal(res.body.label, 'Main Library');
    assert.ok(res.body.id);
    favoriteId = res.body.id;
  });

  await t.test('GET /api/favorites - lists favorite places', async () => {
    const res = await request('/api/favorites', {
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.length, 1);
    assert.equal(res.body[0].id, favoriteId);
  });

  await t.test('PUT /api/favorites/:id - updates favorite place', async () => {
    const res = await request(`/api/favorites/${favoriteId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        label: 'Central Library',
        latitude: 12.9725,
        longitude: 77.5955,
        address: 'Block B, Campus',
        icon: '📖',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.label, 'Central Library');
  });

  await t.test('DELETE /api/favorites/:id - removes favorite place', async () => {
    const res = await request(`/api/favorites/${favoriteId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 204);
  });

  await t.test('POST /api/groups - creates family group', async () => {
    const res = await request('/api/groups', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: { name: 'Study Group' },
    });

    assert.equal(res.status, 201);
    assert.equal(res.body.name, 'Study Group');
    assert.ok(res.body.id);
    assert.ok(res.body.inviteCode);

    groupId = res.body.id;
    inviteCode = res.body.inviteCode;
  });

  await t.test('PUT /api/groups/:id - updates group name', async () => {
    const res = await request(`/api/groups/${groupId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}` },
      body: { name: 'SmartSpot CS Study Group' },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.name, 'SmartSpot CS Study Group');
  });

  await t.test('POST /api/groups/:id/members - adds member to group', async () => {
    const res = await request(`/api/groups/${groupId}/members`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: { memberName: 'Alex' },
    });

    assert.equal(res.status, 201);
    assert.ok(res.body.memberNames.includes('Alex'));
  });

  await t.test('DELETE /api/groups/:id/members/:memberName - removes member', async () => {
    const res = await request(`/api/groups/${groupId}/members/Alex`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 204);
  });

  await t.test('POST /api/groups/join - joins group via invite code', async () => {
    const res = await request('/api/groups/join', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: { inviteCode },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.id, groupId);
  });

  await t.test('DELETE /api/groups/:id - deletes group', async () => {
    const res = await request(`/api/groups/${groupId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 204);
  });

  await t.test('POST /api/visits - logs location visit', async () => {
    const res = await request('/api/visits', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Bookstore',
        category: 'college',
      },
    });

    assert.equal(res.status, 201);
    assert.equal(res.body.locationName, 'Bookstore');
  });

  await t.test('GET /api/visits - retrieves logged visits', async () => {
    const res = await request('/api/visits', {
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.length, 1);
  });

  await t.test('GET /api/analytics/statistics - returns analytics summary', async () => {
    const res = await request('/api/analytics/statistics', {
      headers: { Authorization: `Bearer ${token}` },
    });

    assert.equal(res.status, 200);
    assert.ok(res.body.total >= 0);
  });

  await t.test('POST /api/auth/change-password - changes password', async () => {
    const res = await request('/api/auth/change-password', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        currentPassword: 'Password123',
        newPassword: 'NewSecurePassword123',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.message, 'Password changed successfully');
  });

  await t.test('POST /api/auth/reset-password - resets password via security answer', async () => {
    const res = await request('/api/auth/reset-password', {
      method: 'POST',
      body: {
        email: 'student@example.com',
        securityAnswer: 'Blue',
        newPassword: 'ResetPassword123',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.message, 'Password reset successfully');
  });

  // Teardown
  process.exit(0);
});
