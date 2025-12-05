const test = require('ava');
const { Reader } = require('../index.js');
const fs = require('fs');
const path = require('path');

const fixturePath = path.resolve(__dirname, '../../../tests/fixtures/hello.szst');

test('opens valid archive', t => {
  if (!fs.existsSync(fixturePath)) {
    t.fail('Fixture not found at ' + fixturePath);
    return;
  }
  const reader = new Reader(fixturePath);
  t.is(reader.size, 11);
  t.true(reader.frameCount >= 1);
});

test('reads range correctly', t => {
  if (!fs.existsSync(fixturePath)) {
    t.fail('Fixture not found at ' + fixturePath);
    return;
  }
  const reader = new Reader(fixturePath);
  const data = reader.readRange(0, 5);
  t.is(data.toString(), 'Hello');

  const data2 = reader.readRange(6, 11);
  t.is(data2.toString(), 'World');
});

test('reads range async correctly', async t => {
  if (!fs.existsSync(fixturePath)) {
    t.fail('Fixture not found at ' + fixturePath);
    return;
  }
  const reader = new Reader(fixturePath);
  const data = await reader.readRangeAsync(0, 5);
  t.is(data.toString(), 'Hello');

  const data2 = await reader.readRangeAsync(6, 11);
  t.is(data2.toString(), 'World');
});
