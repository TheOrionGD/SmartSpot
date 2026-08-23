const fs = require('node:fs');
const path = require('node:path');
require('dotenv').config();

const file = process.env.DB_FILE || './data/smartspot.json';
const databasePath = path.resolve(__dirname, '..', file);
fs.mkdirSync(path.dirname(databasePath), { recursive: true });

const defaultCollections = {
  users: [],
  reminders: [],
  favorites: [],
  groups: [],
  groupMembers: [],
  locationVisits: [],
  missedEvents: [],
};

let data = { ...defaultCollections };

if (fs.existsSync(databasePath)) {
  try {
    const parsed = JSON.parse(fs.readFileSync(databasePath, 'utf8'));
    data = { ...defaultCollections, ...parsed };
    // Ensure all default collections exist as arrays
    for (const key of Object.keys(defaultCollections)) {
      if (!Array.isArray(data[key])) {
        data[key] = [];
      }
    }
  } catch {
    console.warn('Could not read the data file; starting with an empty store.');
  }
}

function save() {
  fs.writeFileSync(databasePath, JSON.stringify(data, null, 2));
}

module.exports = {
  all(collection, predicate = () => true) {
    if (!data[collection]) data[collection] = [];
    return data[collection].filter(predicate);
  },

  find(collection, predicate) {
    if (!data[collection]) data[collection] = [];
    return data[collection].find(predicate);
  },

  insert(collection, value) {
    if (!data[collection]) data[collection] = [];
    data[collection].push(value);
    save();
    return value;
  },

  update(collection, predicate, patch) {
    if (!data[collection]) data[collection] = [];
    const item = data[collection].find(predicate);
    if (!item) return null;
    Object.assign(item, patch);
    save();
    return item;
  },

  remove(collection, predicate) {
    if (!data[collection]) data[collection] = [];
    const before = data[collection].length;
    data[collection] = data[collection].filter((item) => !predicate(item));
    if (data[collection].length !== before) save();
    return before - data[collection].length;
  },

  upsert(collection, predicate, value) {
    if (!data[collection]) data[collection] = [];
    const existingIndex = data[collection].findIndex(predicate);
    if (existingIndex >= 0) {
      data[collection][existingIndex] = { ...data[collection][existingIndex], ...value };
      save();
      return data[collection][existingIndex];
    } else {
      data[collection].push(value);
      save();
      return value;
    }
  },

  reset() {
    data = {
      users: [],
      reminders: [],
      favorites: [],
      groups: [],
      groupMembers: [],
      locationVisits: [],
      missedEvents: [],
    };
    save();
  },
};
