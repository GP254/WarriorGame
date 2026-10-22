import test from "node:test";
import assert from "node:assert/strict";
import {
  freshSave,
  parseSave,
  canConquer,
  claimVictory,
  buyWeapon,
  territories,
  weapons,
  families,
} from "../src/data.ts";
import {
  SpatialGrid,
  effectiveDamage,
  meleeInRange,
  animationFrame,
} from "../src/combat.ts";

test("200 distinct weapons, 50 per family, all affordable progression IDs unique", () => {
  assert.equal(new Set(weapons.map((w) => w.id)).size, 200);
  for (const family of families) {
    const group = weapons.filter((w) => w.family === family);
    assert.equal(group.length, 50);
    assert.equal(group[0].cost, 0);
    assert.ok(group.every((w) => w.damage > 0 && w.speed > 0 && w.range > 0));
  }
});
test("campaign routes are reciprocal and every territory can be conquered from home", () => {
  const save = freshSave();
  for (const t of territories)
    for (const n of t.links)
      assert.ok(
        territories[n].links.includes(t.id),
        `${t.name} -> ${territories[n].name}`,
      );
  for (let pass = 0; pass < 16; pass++)
    for (const t of territories)
      if (canConquer(save, t.id)) claimVictory(save, t.id);
  assert.equal(save.owned.length, 16);
  assert.equal(save.wins, 15);
});
test("locked territory and repeat victories never pay duplicate rewards", () => {
  const s = freshSave();
  assert.equal(claimVictory(s, 15), false);
  assert.equal(canConquer(s, 200), false);
  assert.equal(canConquer(s, -1), false);
  assert.equal(claimVictory(s, 1), true);
  const before = JSON.stringify(s);
  assert.equal(claimVictory(s, 1), false);
  assert.equal(JSON.stringify(s), before);
});
test("purchase charges once and rejects unaffordable or nonexistent weapons", () => {
  const s = freshSave(),
    gold = s.gold;
  assert.equal(buyWeapon(s, "swords-1"), true);
  assert.equal(s.gold, gold - 58);
  buyWeapon(s, "swords-1");
  assert.equal(s.gold, gold - 58);
  assert.equal(buyWeapon(s, "swords-49"), false);
  assert.equal(buyWeapon(s, "missing"), false);
});
test("new armies start at 200 and old campaigns migrate without losing progress", () => {
  assert.equal(
    freshSave().squads.reduce((a, b) => a + b, 0),
    200,
  );
  const old = {
    ...freshSave(),
    version: 1,
    squads: [8, 6, 4, 4],
    owned: [0, 1],
    gold: 1700,
    wins: 1,
    day: 2,
  };
  const migrated = parseSave(JSON.stringify(old));
  assert.equal(migrated.version, 2);
  assert.deepEqual(migrated.squads, [80, 60, 40, 40]);
  assert.deepEqual(migrated.owned, [0, 1]);
  assert.equal(migrated.gold, 1700);
});
test("malformed and unowned equipment saves recover safely", () => {
  assert.deepEqual(parseSave("{bad"), freshSave());
  assert.deepEqual(
    parseSave(JSON.stringify({ ...freshSave(), inventory: [] })),
    freshSave(),
  );
  assert.deepEqual(
    parseSave(JSON.stringify({ ...freshSave(), squads: [126, 1, 1, 1] })),
    freshSave(),
  );
  const valid = freshSave();
  valid.squads = [125, 125, 125, 125];
  assert.deepEqual(parseSave(JSON.stringify(valid)), valid);
});
test("spatial lookup agrees with brute force for a 941-warrior field", () => {
  const troops = Array.from({ length: 941 }, (_, i) => ({
    id: i,
    x: ((i * 73) % 2800) - 1400,
    z: ((i * 137) % 2800) - 1400,
  }));
  const grid = new SpatialGrid<(typeof troops)[number]>();
  grid.rebuild(troops);
  for (const origin of troops.filter((_, i) => i % 37 === 0))
    for (const radius of [25, 75, 140, 480]) {
      assert.deepEqual(
        grid
          .near(origin, radius)
          .map((u) => u.id)
          .sort((a, b) => a - b),
        troops
          .filter((u) => meleeInRange(origin, u, radius))
          .map((u) => u.id)
          .sort((a, b) => a - b),
      );
    }
});
test("guard mitigates damage, armor never heals, hit ranges respect boundaries", () => {
  assert.ok(effectiveDamage(40, 20, true) < effectiveDamage(40, 20));
  assert.equal(effectiveDamage(1, 1000), 1);
  assert.equal(meleeInRange({ x: 0, z: 0 }, { x: 3, z: 4 }, 5), true);
  assert.equal(meleeInRange({ x: 0, z: 0 }, { x: 3, z: 4 }, 4.99), false);
});
test("animation progresses through all eight frames and holds final death pose", () => {
  assert.deepEqual(
    Array.from({ length: 8 }, (_, i) => animationFrame(i / 8)),
    [0, 1, 2, 3, 4, 5, 6, 7],
  );
  assert.equal(animationFrame(1), 7);
  assert.equal(animationFrame(20), 7);
  assert.equal(animationFrame(-1), 0);
});

import { Battle, type Unit } from "../src/battle.ts";
function fighter(team: number, player = false): Unit {
  return {
    id: team,
    team,
    type: 1,
    x: 0,
    z: team ? -45 : 0,
    hp: 200,
    max: 200,
    def: 10,
    speed: 0,
    damage: 40,
    range: 75,
    weapon: weapons[0],
    cool: 0,
    attack: 0,
    attackMax: 0,
    heavy: false,
    hit: false,
    stun: 0,
    dead: 0,
    vx: 0,
    vz: 0,
    phase: 0,
    moving: false,
    player,
    block: false,
    dodge: 0,
    think: 100,
    face: team ? 1 : -1,
    hurt: 0,
  };
}
function testBattle() {
  const b = Object.create(Battle.prototype) as Battle,
    p = fighter(0, true),
    enemy = fighter(1);
  Object.assign(b, {
    save: freshSave(),
    territory: territories[1],
    player: p,
    units: [p, enemy],
    grid: new SpatialGrid<Unit>(),
    particles: [],
    arrows: [],
    debris: [],
    stains: [],
    texts: [],
    keys: new Set(),
    active: true,
    paused: false,
    ready: true,
    charge: 0,
    elapsed: 0,
    stamina: 100,
    comboTimer: 0,
    combo: 0,
    shake: 0,
    kills: 0,
    cameraX: 0,
    cameraZ: 0,
    overview: false,
    sound: () => {},
  });
  b.grid.rebuild(b.units);
  return b;
}
test("light strike deals damage once after windup, not at button press", () => {
  const b = testBattle(),
    enemy = b.units[1];
  enemy.cool = 100;
  b.action("slash");
  assert.equal(enemy.hp, 200);
  b.update(0.2);
  assert.equal(enemy.hp, 200);
  b.update(0.2);
  assert.ok(enemy.hp < 200);
  const health = enemy.hp;
  b.update(0.1);
  assert.equal(enemy.hp, health);
});
test("dodge prevents a hit and leader recovery blocks simultaneous crowd damage", () => {
  const b = testBattle(),
    p = b.player,
    enemy = b.units[1];
  p.dodge = 0.3;
  b.hit(enemy, p);
  assert.equal(p.hp, 200);
  p.dodge = 0;
  b.hit(enemy, p);
  assert.ok(p.hp < 200);
  const health = p.hp;
  b.hit(enemy, p);
  assert.equal(p.hp, health);
});
test("heavy attacks kill, enter death animation, and count personal kills once", () => {
  const b = testBattle(),
    enemy = b.units[1];
  enemy.hp = 20;
  b.hit(b.player, enemy, 1.85);
  assert.equal(enemy.hp, 0);
  assert.ok(enemy.dead > 0);
  assert.equal(b.kills, 1);
  b.hit(b.player, enemy, 1.85);
  assert.equal(b.kills, 1);
});
test("turning blood off suppresses blood particles, stains, and debris", () => {
  const b = testBattle();
  b.save.settings.blood = false;
  b.units[1].hp = 1;
  b.hit(b.player, b.units[1], 2);
  assert.equal(b.particles.length, 0);
  assert.equal(b.stains.length, 0);
  assert.equal(b.debris.length, 0);
});
test("rally heals only living allies inside its radius and consumes stamina", () => {
  const b = testBattle(),
    near = { ...fighter(0), id: 2, x: 100, hp: 50 },
    far = { ...fighter(0), id: 3, x: 600, hp: 50 };
  b.units.push(near, far);
  b.grid.rebuild(b.units);
  b.action("rally");
  assert.equal(near.hp, 75);
  assert.equal(far.hp, 50);
  assert.equal(b.stamina, 35);
});
