const test = require('ava');
const { Reader } = require('../index.js');
const fs = require('fs');
const path = require('path');

const fixturePath = path.resolve(__dirname, '../../tests/fixtures/hello.szst');

test('opens valid archive', t => {
  if (!fs.existsSync(fixturePath)) {
    t.fail('Fixture not found');
    return;
  }
  const reader = new Reader(fixturePath);
  t.is(reader.size, 11n);
  t.true(reader.frameCount >= 1n);
});

test('reads range correctly', t => {
  if (!fs.existsSync(fixturePath)) {
    t.fail('Fixture not found');
    return;
  }
  const reader = new Reader(fixturePath);
  const data = reader.readRange(0n, 5n);
  t.is(data.toString(), 'Hello');
  
  const data2 = reader.readRange(6n, 11n);
  t.is(data2.toString(), 'World');
});
