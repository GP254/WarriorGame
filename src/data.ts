export type Family = "swords" | "axes" | "spears" | "bows";
export const families: Family[] = ["swords", "axes", "spears", "bows"];
export const classes = [
  {
    name: "Ironward",
    role: "Shield infantry",
    hp: 125,
    def: 12,
    speed: 78,
    weapon: "swords",
    desc: "Hold the line. Balanced steel and a steadfast shield.",
  },
  {
    name: "Ravager",
    role: "Shock infantry",
    hp: 105,
    def: 5,
    speed: 90,
    weapon: "axes",
    desc: "Break their guard with sweeping, heavy blows.",
  },
  {
    name: "Pikewarden",
    role: "Reach & control",
    hp: 100,
    def: 8,
    speed: 74,
    weapon: "spears",
    desc: "Keep enemies at a distance. Punish a reckless charge.",
  },
  {
    name: "Duskranger",
    role: "Ranged support",
    hp: 78,
    def: 3,
    speed: 85,
    weapon: "bows",
    desc: "Loose arrows from behind the line. Vulnerable up close.",
  },
] as const;
const materials = [
  "Weathered",
  "Iron",
  "Bronze",
  "Tempered",
  "Blacksteel",
  "Gilded",
  "Frostbound",
  "Obsidian",
  "Runic",
  "Sovereign",
];
const shapes: Record<Family, string[]> = {
  swords: ["Shortsword", "Falchion", "Longsword", "Saber", "Greatsword"],
  axes: ["Hatchet", "Bearded Axe", "War Axe", "Double Axe", "Executioner"],
  spears: ["Hunting Spear", "Pike", "Partisan", "Glaive", "Halberd"],
  bows: ["Shortbow", "Hunting Bow", "Recurve", "Longbow", "War Bow"],
};
export const weapons = families.flatMap((family, f) =>
  Array.from({ length: 50 }, (_, i) => ({
    id: `${family}-${i}`,
    family,
    index: i,
    name: `${materials[Math.floor(i / 5)]} ${shapes[family][i % 5]}`,
    tier: Math.floor(i / 10),
    cost: i === 0 ? 0 : 50 + Math.round(i ** 1.45) * 8,
    damage: Math.round(16 + i * 1.25 + [0, 8, 1, -2][f] + (i % 5) * 1.5),
    speed: [1.0, 0.76, 0.86, 1.1][f] - (i % 5) * 0.035,
    range: [75, 85, 125, 480][f],
    rarity: ["Common", "Uncommon", "Rare", "Epic", "Legendary"][
      Math.floor(i / 10)
    ],
  })),
);
export const armors = [
  {
    name: "Scout leathers",
    def: 2,
    hp: 0,
    speed: 1.12,
    cost: 0,
    wood: 0,
    iron: 0,
  },
  {
    name: "Riveted mail",
    def: 9,
    hp: 20,
    speed: 1,
    cost: 160,
    wood: 0,
    iron: 15,
  },
  {
    name: "Warden plate",
    def: 18,
    hp: 45,
    speed: 0.86,
    cost: 420,
    wood: 10,
    iron: 35,
  },
  {
    name: "Sovereign armor",
    def: 28,
    hp: 70,
    speed: 0.8,
    cost: 980,
    wood: 20,
    iron: 70,
  },
];
export interface Territory {
  id: number;
  name: string;
  type: string;
  x: number;
  y: number;
  biome: number;
  level: number;
  enemies: number;
  gold: number;
  wood: number;
  iron: number;
  links: number[];
  desc: string;
}
const locations: [
  string,
  string,
  number,
  number,
  number,
  number,
  number,
  number,
  number,
  number,
  number[],
  string,
][] = [
  [
    "Hearthhold",
    "Your stronghold",
    44,
    40,
    0,
    0,
    0,
    0,
    0,
    0,
    [1, 2, 3],
    "The last fire in a fractured land. Your clan’s home, and the beginning of its story.",
  ],
  [
    "Ravenwood",
    "Woodland village",
    59,
    50,
    0,
    1,
    18,
    260,
    80,
    15,
    [0, 4, 5],
    "Smoke rises beyond the old bridge. Take the timber settlement and give your clan a foothold in the eastern woods.",
  ],
  [
    "The Old Crossing",
    "River outpost",
    37,
    49,
    0,
    1,
    16,
    210,
    35,
    25,
    [0, 6, 7],
    "A narrow crossing held by a ragged warband. Whoever holds the bridge controls the valley.",
  ],
  [
    "Briarwatch",
    "Forest watchtower",
    43,
    28,
    0,
    2,
    22,
    320,
    60,
    40,
    [0, 8, 9],
    "Archers watch from the timber walls. Close the distance before their arrows find your line.",
  ],
  [
    "Mirehollow",
    "Marsh settlement",
    73,
    63,
    2,
    3,
    25,
    380,
    45,
    55,
    [1, 10, 11],
    "Drowned roads and low mist hide the defenders of this forsaken village.",
  ],
  [
    "Alder Fields",
    "Farming village",
    47,
    67,
    0,
    2,
    20,
    300,
    100,
    20,
    [1, 7, 12],
    "The harvest lies untouched. Break the occupying warband and secure provisions for your people.",
  ],
  [
    "Saltwind Keep",
    "Coastal fortress",
    19,
    42,
    0,
    3,
    28,
    440,
    45,
    70,
    [2, 13],
    "A salt-worn fortress overlooking the western sea. Towers rain arrows over the approach.",
  ],
  [
    "Emberfall",
    "Mining village",
    25,
    65,
    0,
    2,
    24,
    340,
    40,
    85,
    [2, 5, 12],
    "Old furnaces still burn beneath the cliffs. Its iron will arm the next generation of your clan.",
  ],
  [
    "Frostgate",
    "Mountain fortress",
    65,
    13,
    1,
    5,
    36,
    680,
    60,
    120,
    [3, 9, 13, 14],
    "A frozen gate at the roof of the world. Heavy infantry and tower archers hold its ancient walls.",
  ],
  [
    "Wolfpine",
    "Highland encampment",
    59,
    32,
    1,
    3,
    26,
    420,
    80,
    50,
    [3, 8, 10],
    "Rival hunters guard the high pass. Their spears and longbows make every approach dangerous.",
  ],
  [
    "Blackfen",
    "Ruined citadel",
    88,
    55,
    2,
    4,
    32,
    540,
    50,
    95,
    [4, 9, 14],
    "The water remembers another kingdom. Armored sentries patrol what remains of its walls.",
  ],
  [
    "Drowned Abbey",
    "Marsh ruins",
    80,
    76,
    2,
    4,
    30,
    520,
    70,
    80,
    [4, 12, 15],
    "Bells no longer ring here. A hardened warband has turned the old abbey into a stronghold.",
  ],
  [
    "Gull’s Rest",
    "Trading harbor",
    34,
    79,
    0,
    3,
    26,
    500,
    70,
    45,
    [5, 7, 11],
    "A sheltered harbor and a road to the southern coast. Wealth waits behind its palisade.",
  ],
  [
    "Stormreach",
    "Cliffside fortress",
    11,
    17,
    1,
    5,
    38,
    720,
    90,
    130,
    [6, 8],
    "The storm-lashed western bastion. Its defenders have never seen another banner on their walls.",
  ],
  [
    "Cinder Spire",
    "Ashland citadel",
    88,
    16,
    3,
    6,
    42,
    900,
    100,
    160,
    [8, 10, 15],
    "Beyond the black ridge, a crimson banner flies. Take the spire and break the strongest clan in the frontier.",
  ],
  [
    "The Last Bastion",
    "Border stronghold",
    94,
    39,
    3,
    6,
    44,
    1100,
    120,
    180,
    [11, 14],
    "At the edge of the known world stands the final stronghold. Let your banner rise over all the frontier.",
  ],
];
export const territories: Territory[] = locations.map((a, id) => {
  const [
    name,
    type,
    x,
    y,
    biome,
    level,
    enemies,
    gold,
    wood,
    iron,
    links,
    desc,
  ] = a;
  return {
    id,
    name,
    type,
    x,
    y,
    biome,
    level,
    enemies: enemies * 10,
    gold,
    wood,
    iron,
    links,
    desc,
  };
});
export interface Save {
  version: 2;
  gold: number;
  wood: number;
  iron: number;
  owned: number[];
  inventory: string[];
  equipped: string[];
  armor: number[];
  armorOwned: number[];
  squads: number[];
  leader: number;
  day: number;
  wins: number;
  settings: { blood: boolean; sound: boolean; shake: boolean };
}
export const freshSave = (): Save => ({
  version: 2,
  gold: 1250,
  wood: 240,
  iron: 120,
  owned: [0],
  inventory: families.map((f) => `${f}-0`),
  equipped: families.map((f) => `${f}-0`),
  armor: [1, 0, 1, 0],
  armorOwned: [0, 1],
  squads: [60, 50, 50, 40],
  leader: 0,
  day: 1,
  wins: 0,
  settings: { blood: true, sound: true, shake: true },
});
export function canConquer(s: Save, id: number) {
  return (
    Number.isInteger(id) &&
    !!territories[id] &&
    !s.owned.includes(id) &&
    territories[id].links.some((n) => s.owned.includes(n))
  );
}
export function buyWeapon(s: Save, id: string) {
  const w = weapons.find((w) => w.id === id);
  if (!w) return false;
  if (s.inventory.includes(id)) return true;
  if (s.gold < w.cost) return false;
  s.gold -= w.cost;
  s.inventory.push(id);
  return true;
}
export function claimVictory(s: Save, id: number) {
  if (!canConquer(s, id)) return false;
  const t = territories[id];
  s.owned.push(id);
  s.gold += t.gold;
  s.wood += t.wood;
  s.iron += t.iron;
  s.day++;
  s.wins++;
  return true;
}
export function parseSave(raw: string | null): Save {
  const fallback = freshSave();
  try {
    const v = JSON.parse(raw || "null");
    if (v?.version === 1 && Array.isArray(v.squads)) {
      v.squads = v.squads.map((n: number) => Math.min(125, n * 10));
      v.version = 2;
    }
    const ints = (
      values: unknown,
      min: number,
      max: number,
    ): values is number[] =>
      Array.isArray(values) &&
      values.every((n) => Number.isInteger(n) && n >= min && n <= max);
    const weaponIds = new Set(weapons.map((w) => w.id));
    if (
      !v ||
      v.version !== 2 ||
      !ints(v.owned, 0, territories.length - 1) ||
      !v.owned.includes(0) ||
      new Set(v.owned).size !== v.owned.length
    )
      return fallback;
    if (
      ![v.gold, v.wood, v.iron].every((n) => Number.isSafeInteger(n) && n >= 0)
    )
      return fallback;
    if (
      !ints(v.squads, 0, 125) ||
      v.squads.length !== 4 ||
      !ints(v.armor, 0, armors.length - 1) ||
      v.armor.length !== 4 ||
      !ints(v.armorOwned, 0, armors.length - 1)
    )
      return fallback;
    if (
      !Array.isArray(v.inventory) ||
      !v.inventory.every(
        (id: unknown) => typeof id === "string" && weaponIds.has(id),
      )
    )
      return fallback;
    if (
      !Array.isArray(v.equipped) ||
      v.equipped.length !== 4 ||
      !v.equipped.every(
        (id: unknown) => v.inventory.includes(id) && weaponIds.has(String(id)),
      )
    )
      return fallback;
    if (
      !v.armor.every((id: number) => v.armorOwned.includes(id)) ||
      !families.every((f) => v.inventory.includes(`${f}-0`))
    )
      return fallback;
    if (
      !Number.isInteger(v.leader) ||
      v.leader < 0 ||
      v.leader > 3 ||
      !Number.isSafeInteger(v.day) ||
      v.day < 1 ||
      !Number.isInteger(v.wins) ||
      v.wins < 0 ||
      v.wins > 15
    )
      return fallback;
    const settings = { ...fallback.settings };
    for (const key of ["blood", "sound", "shake"] as const)
      if (typeof v.settings?.[key] === "boolean")
        settings[key] = v.settings[key];
    return {
      version: 2,
      gold: v.gold,
      wood: v.wood,
      iron: v.iron,
      owned: v.owned,
      inventory: v.inventory,
      equipped: v.equipped,
      armor: v.armor,
      armorOwned: v.armorOwned,
      squads: v.squads,
      leader: v.leader,
      day: v.day,
      wins: v.wins,
      settings,
    };
  } catch {
    return fallback;
  }
}
export function loadSave(): Save {
  try {
    return parseSave(
      localStorage.getItem("ashen-banner-v2") ||
        localStorage.getItem("ashen-banner-v1"),
    );
  } catch {
    return freshSave();
  }
}
