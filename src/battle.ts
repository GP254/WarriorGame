import { classes, armors, weapons, type Save, type Territory } from "./data";
import {
  SpatialGrid,
  effectiveDamage,
  meleeInRange,
  animationFrame,
} from "./combat";
export { effectiveDamage, meleeInRange } from "./combat";
export interface BattleResult {
  win: boolean;
  kills: number;
  survivors: number;
  seconds: number;
}
type Weapon = (typeof weapons)[number];
export interface Unit {
  id: number;
  team: number;
  type: number;
  x: number;
  z: number;
  hp: number;
  max: number;
  def: number;
  speed: number;
  damage: number;
  range: number;
  weapon: Weapon;
  cool: number;
  attack: number;
  attackMax: number;
  heavy: boolean;
  hit: boolean;
  stun: number;
  dead: number;
  vx: number;
  vz: number;
  phase: number;
  moving: boolean;
  player: boolean;
  block: boolean;
  dodge: number;
  target?: Unit;
  think: number;
  face: number;
  hurt: number;
}
interface Particle {
  x: number;
  z: number;
  y: number;
  vx: number;
  vz: number;
  vy: number;
  life: number;
  color: string;
  size: number;
}
interface Arrow {
  x: number;
  z: number;
  y: number;
  vx: number;
  vz: number;
  time: number;
  duration: number;
  source: Unit;
  target: Unit;
  heavy: boolean;
}
interface Debris {
  x: number;
  z: number;
  y: number;
  vx: number;
  vz: number;
  vy: number;
  angle: number;
  spin: number;
  life: number;
  type: number;
  team: number;
}
const clamp = (n: number, a: number, b: number) => Math.max(a, Math.min(b, n));
const sheetNames = ["ironward", "ravager", "pikewarden", "duskranger"];
const attackType = (w: Weapon) =>
  w.family === "axes"
    ? 1
    : w.family === "spears"
      ? 2
      : w.family === "bows"
        ? 3
        : 0;
export class Battle {
  ctx: CanvasRenderingContext2D;
  units: Unit[] = [];
  player!: Unit;
  grid = new SpatialGrid<Unit>();
  frames: HTMLCanvasElement[][] = [];
  terrain = new Image();
  ground?: HTMLCanvasElement;
  particles: Particle[] = [];
  arrows: Arrow[] = [];
  debris: Debris[] = [];
  stains: { x: number; z: number; r: number }[] = [];
  texts: { x: number; z: number; text: string; life: number; color: string }[] =
    [];
  keys = new Set<string>();
  active = true;
  paused = false;
  ready = false;
  elapsed = 0;
  charge = 2.8;
  stamina = 100;
  kills = 0;
  width = 1280;
  height = 720;
  cameraX = 0;
  cameraZ = 0;
  zoom = 0.75;
  zoomFactor = 1;
  overview = false;
  shake = 0;
  hitstop = 0;
  combo = 0;
  comboTimer = 0;
  raf = 0;
  last = 0;
  hudAt = 0;
  fps = 60;
  audio?: AudioContext;
  lastAudio = 0;
  cleanup: (() => void)[] = [];
  endTimer?: ReturnType<typeof setTimeout>;
  constructor(
    public canvas: HTMLCanvasElement,
    public save: Save,
    public territory: Territory,
    public onEnd: (r: BattleResult) => void,
    formation = "balanced",
    deployment = save.squads,
  ) {
    this.ctx = canvas.getContext("2d")!;
    let id = 0;
    const create = (
      team: number,
      type: number,
      x: number,
      z: number,
      player = false,
    ): Unit => {
      const armor = team
        ? armors[Math.min(2, Math.floor(territory.level / 3))]
        : armors[save.armor[type]];
      const weapon = weapons.find(
        (w) =>
          w.id ===
          (team
            ? `${classes[type].weapon}-${Math.min(35, territory.level * 3)}`
            : save.equipped[type]),
      )!;
      const hp =
        (classes[type].hp + armor.hp) *
        (player ? 3.2 : team ? 0.95 + territory.level * 0.05 : 1);
      return {
        id: id++,
        team,
        type,
        x,
        z,
        hp,
        max: hp,
        def: classes[type].def + armor.def,
        speed: classes[type].speed * armor.speed,
        damage: weapon.damage * (player ? 2.4 : team ? 0.88 : 1),
        range: weapon.range,
        weapon,
        cool: Math.random() * 0.8,
        attack: 0,
        attackMax: 0,
        heavy: false,
        hit: false,
        stun: 0,
        dead: 0,
        vx: 0,
        vz: 0,
        phase: Math.random() * 8,
        moving: false,
        player,
        block: false,
        dodge: 0,
        think: Math.random() * 0.2,
        face: team ? 1 : -1,
        hurt: 0,
      };
    };
    let n = 0;
    const total = deployment.reduce((a, b) => a + b, 0);
    const columns = Math.min(30, Math.max(12, Math.ceil(Math.sqrt(total * 3))));
    deployment.forEach((count, type) => {
      for (let i = 0; i < count; i++) {
        let x = ((n % columns) - (columns - 1) / 2) * 36,
          z = 360 + Math.floor(n / columns) * 38;
        if (formation === "wedge") {
          const row = Math.floor(Math.sqrt(n));
          x = (n - row * row - row) * 31;
          z = 360 + row * 27;
        }
        if (formation === "shield") {
          x = ((i % 25) - 12) * 36;
          z = 360 + Math.floor(i / 25) * 38 + type * 110;
        }
        this.units.push(create(0, type, x, z));
        n++;
      }
    });
    this.player = create(0, save.leader, 0, 330, true);
    this.units.push(this.player);
    const enemyColumns = Math.min(
      30,
      Math.max(12, Math.ceil(Math.sqrt(territory.enemies * 3))),
    );
    for (let i = 0; i < territory.enemies; i++)
      this.units.push(
        create(
          1,
          i < territory.enemies * 0.8 ? i % 3 : 3,
          ((i % enemyColumns) - (enemyColumns - 1) / 2) * 36,
          -360 - Math.floor(i / enemyColumns) * 38,
        ),
      );
    this.bindInput();
    this.resize();
    this.loadArt();
    this.raf = requestAnimationFrame((t) => this.loop(t));
  }
  private async loadArt() {
    try {
      const sheets = sheetNames.map((name) => {
        const img = new Image();
        img.src = `/assets/${name}-v2.png`;
        return img;
      });
      this.terrain.src = "/assets/terrain-v2.png";
      await Promise.all([...sheets, this.terrain].map((img) => img.decode()));
      // Cache exact grid cells at native display resolution. Animation samples whole poses.
      this.frames = sheets.map((sheet) =>
        Array.from({ length: 64 }, (_, index) => {
          const frame = document.createElement("canvas");
          frame.width = 96;
          frame.height = 96;
          frame
            .getContext("2d")!
            .drawImage(
              sheet,
              ((index % 8) * sheet.width) / 8,
              (Math.floor(index / 8) * sheet.height) / 8,
              sheet.width / 8,
              sheet.height / 8,
              0,
              0,
              96,
              96,
            );
          return frame;
        }),
      );
      this.ground = document.createElement("canvas");
      this.ground.width = 1536;
      this.ground.height = 1536;
      const b = this.territory.biome;
      this.ground
        .getContext("2d")!
        .drawImage(
          this.terrain,
          ((b % 2) * this.terrain.width) / 2,
          (Math.floor(b / 2) * this.terrain.height) / 2,
          this.terrain.width / 2,
          this.terrain.height / 2,
          0,
          0,
          1536,
          1536,
        );
      this.ready = true;
    } catch {
      this.active = false;
      const el = document.querySelector("#battle-message");
      if (el)
        el.textContent =
          "Could not load the animation sheets. Return to the map and retry.";
    }
  }
  private bindInput() {
    const down = (e: KeyboardEvent) => {
      if (
        [
          "Space",
          "ArrowUp",
          "ArrowDown",
          "ArrowLeft",
          "ArrowRight",
          "KeyJ",
          "KeyK",
          "KeyL",
          "KeyE",
          "KeyQ",
          "Tab",
        ].includes(e.code)
      )
        e.preventDefault();
      this.keys.add(e.code);
      if (e.repeat) return;
      if (e.code === "KeyJ") this.action("slash");
      if (e.code === "KeyK") this.action("heavy");
      if (e.code === "Space") this.action("dodge");
      if (e.code === "KeyE") this.action("rally");
      if (e.code === "Escape") this.togglePause();
      if (e.code === "Tab") this.setOverview(!this.overview);
    };
    const up = (e: KeyboardEvent) => this.keys.delete(e.code);
    const blur = () => {
      this.keys.clear();
      if (this.active && this.ready && !this.paused) this.togglePause();
    };
    const resize = () => this.resize();
    const wheel = (e: WheelEvent) => {
      e.preventDefault();
      this.zoomFactor = clamp(this.zoomFactor - e.deltaY * 0.001, 0.55, 1.85);
      this.resize();
    };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    window.addEventListener("resize", resize);
    this.canvas.addEventListener("wheel", wheel, { passive: false });
    this.cleanup.push(() => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", blur);
      window.removeEventListener("resize", resize);
      this.canvas.removeEventListener("wheel", wheel);
    });
  }
  resize() {
    this.width = this.canvas.clientWidth;
    this.height = this.canvas.clientHeight;
    const ratio = Math.min(1.5, window.devicePixelRatio || 1);
    this.canvas.width = this.width * ratio;
    this.canvas.height = this.height * ratio;
    this.ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    this.zoom = clamp(this.width / 1550, 0.38, 1) * this.zoomFactor;
  }
  setOverview(value: boolean) {
    this.overview = value;
    document
      .querySelector('[data-action="overview"]')
      ?.classList.toggle("active", value);
  }
  togglePause() {
    if (!this.active) return;
    this.paused = !this.paused;
    this.keys.clear();
    document
      .querySelector("#pause-panel")
      ?.classList.toggle("hidden", !this.paused);
  }
  sound(kind: "hit" | "block" | "horn" | "swing") {
    if (!this.save.settings.sound) return;
    const now = performance.now();
    if (kind === "hit" && now - this.lastAudio < 100) return;
    this.lastAudio = now;
    try {
      this.audio ??= new AudioContext();
      if (this.audio.state === "suspended") void this.audio.resume();
      const o = this.audio.createOscillator(),
        g = this.audio.createGain();
      o.connect(g);
      g.connect(this.audio.destination);
      o.type = kind === "horn" ? "sawtooth" : "triangle";
      o.frequency.setValueAtTime(
        kind === "block"
          ? 650
          : kind === "horn"
            ? 96
            : kind === "swing"
              ? 210
              : 90,
        this.audio.currentTime,
      );
      o.frequency.exponentialRampToValueAtTime(
        35,
        this.audio.currentTime + 0.2,
      );
      g.gain.setValueAtTime(
        kind === "horn" ? 0.05 : 0.025,
        this.audio.currentTime,
      );
      g.gain.exponentialRampToValueAtTime(
        0.001,
        this.audio.currentTime + (kind === "horn" ? 0.8 : 0.22),
      );
      o.start();
      o.stop(this.audio.currentTime + 1);
    } catch {}
  }
  action(kind: string) {
    if (
      !this.active ||
      this.paused ||
      !this.ready ||
      this.charge > 0 ||
      this.player.hp <= 0
    )
      return;
    const p = this.player;
    if (kind === "guard") {
      this.keys.add("KeyL");
      return;
    }
    if (kind === "rally" && this.stamina >= 65) {
      this.stamina -= 65;
      for (const u of this.grid.near(p, 300))
        if (!u.team && u.hp > 0) {
          u.hp = Math.min(u.max, u.hp + 25);
          u.cool = 0;
        }
      this.texts.push({
        x: p.x,
        z: p.z,
        text: "FOR THE CLAN",
        life: 1.5,
        color: "#e4d09d",
      });
      this.sound("horn");
      return;
    }
    if (kind === "dodge" && this.stamina >= 24 && p.dodge <= 0) {
      this.stamina -= 24;
      p.dodge = 0.35;
      p.vx = (this.keys.has("KeyA") ? -1 : this.keys.has("KeyD") ? 1 : 1) * 500;
      p.vz = this.keys.has("KeyS") ? 200 : -100;
      return;
    }
    if (
      (kind === "slash" || kind === "heavy") &&
      p.attack <= 0 &&
      p.cool <= 0 &&
      p.stun <= 0
    ) {
      const heavy = kind === "heavy",
        cost = heavy ? 28 : 12;
      if (this.stamina < cost) return;
      this.stamina -= cost;
      this.combo = this.comboTimer > 0 ? (this.combo + 1) % 3 : 0;
      this.comboTimer = 1.6;
      this.beginAttack(p, heavy);
      this.sound("swing");
    }
  }
  beginAttack(u: Unit, heavy: boolean) {
    u.heavy = heavy;
    u.attackMax = (heavy ? 1.05 : 0.66) / u.weapon.speed;
    u.attack = u.attackMax;
    u.hit = false;
    u.cool = u.attackMax + (u.player ? 0.06 : 0.2 + Math.random() * 0.45);
  }
  hit(source: Unit, target: Unit, mult = 1) {
    if (
      target.hp <= 0 ||
      target.dodge > 0 ||
      (target.player && target.hurt > 0)
    )
      return;
    if (target.player) target.hurt = 0.3;
    const guard = target.player
      ? target.block
      : target.type === 0 && target.attack <= 0 && Math.random() < 0.2;
    const damage = effectiveDamage(source.damage * mult, target.def, guard);
    target.hp = Math.max(0, target.hp - damage);
    target.stun = guard ? 0.04 : mult > 1 ? 0.28 : 0.1;
    const dx = target.x - source.x,
      dz = target.z - source.z,
      len = Math.hypot(dx, dz) || 1;
    target.vx = (dx / len) * (guard ? 18 : mult > 1 ? 170 : 65);
    target.vz = (dz / len) * (guard ? 18 : mult > 1 ? 170 : 65);
    if (guard || this.save.settings.blood)
      for (let i = 0; i < (guard ? 3 : 6); i++)
        this.particles.push({
          x: target.x,
          z: target.z,
          y: 22,
          vx: (Math.random() - 0.5) * 100,
          vz: (Math.random() - 0.5) * 80,
          vy: 35 + Math.random() * 70,
          life: 0.35 + Math.random() * 0.35,
          color: guard ? "#f5dba0" : ["#8d2527", "#b64537", "#5a171d"][i % 3],
          size: 1.5 + Math.random() * 2,
        });
    if (source.player || target.player) {
      this.texts.push({
        x: target.x,
        z: target.z,
        text: guard ? "BLOCK" : String(damage),
        life: 0.65,
        color: guard ? "#b2d5c4" : source.player ? "#efd693" : "#e99a87",
      });
      this.sound(guard ? "block" : "hit");
      this.shake = mult > 1 ? 5 : 2;
      if (source.player) this.hitstop = 0.025;
      if (target.player && guard) {
        this.stamina = Math.max(0, this.stamina - 9);
        if (!this.stamina) {
          target.stun = 0.7;
          this.keys.delete("KeyL");
        }
      }
    }
    if (target.hp <= 0) {
      target.dead = 0.001;
      target.attack = 0;
      target.vx *= 1.5;
      target.vz *= 1.5;
      if (source.player) this.kills++;
      if (this.save.settings.blood) {
        this.stains.push({
          x: target.x,
          z: target.z,
          r: 10 + Math.random() * 10,
        });
        if (mult > 1.3)
          this.debris.push({
            x: target.x,
            z: target.z,
            y: 25,
            vx: target.vx + Math.random() * 40,
            vz: target.vz,
            vy: 80,
            angle: 0,
            spin: Math.random() * 10 - 5,
            life: 3,
            type: target.type,
            team: target.team,
          });
      }
    }
  }
  fire(u: Unit, target: Unit) {
    const duration = Math.max(
      0.1,
      Math.hypot(target.x - u.x, target.z - u.z) / 650,
    );
    this.arrows.push({
      x: u.x,
      z: u.z,
      y: 26,
      vx: (target.x - u.x) / duration,
      vz: (target.z - u.z) / duration,
      time: 0,
      duration,
      source: u,
      target,
      heavy: u.heavy,
    });
  }
  private findTarget(u: Unit, enemies: Unit[]) {
    // Local spatial search. A rare global fallback avoids stranded survivors at the field edge.
    let candidates = this.grid
      .near(u, u.weapon.family === "bows" ? 550 : 220)
      .filter((t) => t.team !== u.team && t.hp > 0);
    if (!candidates.length) candidates = enemies;
    let best: Unit | undefined,
      dist = Infinity;
    for (const t of candidates) {
      const d = (t.x - u.x) ** 2 + (t.z - u.z) ** 2;
      if (d < dist) {
        best = t;
        dist = d;
      }
    }
    u.target = best;
    u.think = 0.18 + Math.random() * 0.12;
  }
  update(dt: number) {
    this.elapsed += dt;
    this.comboTimer -= dt;
    this.stamina = clamp(
      this.stamina + dt * (this.player.block ? 3 : 18),
      0,
      100,
    );
    this.shake = Math.max(0, this.shake - dt * 22);
    if (this.charge > 0) {
      this.charge -= dt;
      for (const u of this.units) {
        u.z += (u.team ? 1 : -1) * dt * 120;
        u.moving = true;
        u.phase += dt * 12;
      }
      if (this.charge <= 0) this.sound("horn");
      this.updateCamera(dt);
      return;
    }
    const alive = this.units.filter((u) => u.hp > 0),
      allies = alive.filter((u) => !u.team),
      enemies = alive.filter((u) => u.team);
    this.grid.rebuild(alive);
    if (!enemies.length || this.player.hp <= 0) {
      this.active = false;
      this.endTimer = setTimeout(() => {
        if (this.canvas.isConnected)
          this.onEnd({
            win: !enemies.length && this.player.hp > 0,
            kills: this.kills,
            survivors: allies.length,
            seconds: Math.floor(this.elapsed),
          });
      }, 1200);
      return;
    }
    for (const u of this.units) {
      u.cool -= dt;
      u.hurt = Math.max(0, u.hurt - dt);
      u.stun = Math.max(0, u.stun - dt);
      u.dodge = Math.max(0, u.dodge - dt);
      u.x += u.vx * dt;
      u.z += u.vz * dt;
      u.vx *= Math.exp(-dt * 7);
      u.vz *= Math.exp(-dt * 7);
      u.moving = false;
      if (u.hp <= 0) {
        u.dead += dt;
        continue;
      }
      if (u.player) {
        u.block =
          (this.keys.has("KeyL") ||
            this.keys.has("ShiftLeft") ||
            this.keys.has("ShiftRight")) &&
          this.stamina > 0 &&
          u.attack <= 0;
        const dx =
          Number(this.keys.has("KeyD") || this.keys.has("ArrowRight")) -
          Number(this.keys.has("KeyA") || this.keys.has("ArrowLeft"));
        const dz =
          Number(this.keys.has("KeyS") || this.keys.has("ArrowDown")) -
          Number(this.keys.has("KeyW") || this.keys.has("ArrowUp"));
        if (u.stun <= 0) {
          const len = Math.hypot(dx, dz) || 1,
            speed =
              u.speed * 2.6 * (u.block ? 0.42 : 1) * (u.attack > 0 ? 0.45 : 1);
          u.x += (dx / len) * speed * dt;
          u.z += (dz / len) * speed * dt;
          u.moving = !!(dx || dz);
        }
        if (this.keys.has("KeyJ")) this.action("slash");
      } else {
        u.think -= dt;
        if (u.think <= 0 || !u.target || u.target.hp <= 0)
          this.findTarget(u, u.team ? allies : enemies);
        const t = u.target;
        if (t && u.stun <= 0 && u.attack <= 0) {
          const dx = t.x - u.x,
            dz = t.z - u.z,
            dist = Math.hypot(dx, dz) || 1,
            ranged = u.weapon.family === "bows";
          const desired = ranged ? 340 : Math.max(28, u.range * 0.58);
          if (dist > desired) {
            u.x += (dx / dist) * u.speed * dt;
            u.z += (dz / dist) * u.speed * dt;
            u.moving = true;
          } else if (u.cool <= 0) this.beginAttack(u, Math.random() < 0.23);
          // Rear sprites for allies; front sprites for the army charging toward them.
          u.face = u.team ? 1 : -1;
        }
      }
      if (u.attack > 0) {
        u.attack -= dt;
        const progress = 1 - u.attack / u.attackMax;
        if (progress >= 0.52 && !u.hit) {
          u.hit = true;
          if (u.weapon.family === "bows") {
            const targets = this.grid
              .near(u, u.range)
              .filter((t) => t.team !== u.team && t.hp > 0);
            targets.sort(
              (a, b) =>
                (a.x - u.x) ** 2 +
                (a.z - u.z) ** 2 -
                ((b.x - u.x) ** 2 + (b.z - u.z) ** 2),
            );
            if (targets[0]) this.fire(u, targets[0]);
          } else {
            const range =
              u.range * (u.player ? 1.2 : 0.85) * (u.heavy ? 1.15 : 1);
            const targets = this.grid
              .near(u, range)
              .filter(
                (t) =>
                  t.hp > 0 &&
                  t.team !== u.team &&
                  (!u.player || t.z < u.z + range * 0.4),
              );
            targets.sort(
              (a, b) =>
                (a.x - u.x) ** 2 +
                (a.z - u.z) ** 2 -
                ((b.x - u.x) ** 2 + (b.z - u.z) ** 2),
            );
            for (const target of targets.slice(
              0,
              u.heavy ? (u.player ? 6 : 2) : u.player ? 3 : 1,
            ))
              this.hit(
                u,
                target,
                u.heavy ? 1.85 : 1 + (u.player ? this.combo * 0.15 : 0),
              );
          }
        }
      }
      u.phase += dt * (u.moving ? 12 : 2);
      u.x = clamp(u.x, -1450, 1450);
      u.z = clamp(u.z, -1450, 1450);
    }
    this.grid.rebuild(alive);
    for (const a of alive)
      for (const b of this.grid.near(a, 25)) {
        if (b.id <= a.id) continue;
        const dx = b.x - a.x,
          dz = b.z - a.z,
          d = Math.hypot(dx, dz);
        if (d < 24 && d > 0.001) {
          const push = (24 - d) * 0.48,
            nx = dx / d,
            nz = dz / d;
          a.x -= nx * push;
          a.z -= nz * push;
          b.x += nx * push;
          b.z += nz * push;
        }
      }
    this.arrows = this.arrows.filter((a) => {
      a.time += dt;
      a.x += a.vx * dt;
      a.z += a.vz * dt;
      a.y = 26 + Math.sin((a.time / a.duration) * Math.PI) * 80;
      if (a.time >= a.duration) {
        if (a.target.hp > 0 && meleeInRange(a, a.target, 32))
          this.hit(a.source, a.target, a.heavy ? 1.4 : 0.85);
        return false;
      }
      return true;
    });
    if (
      (this.territory.type.includes("fortress") ||
        this.territory.type.includes("tower") ||
        this.territory.level >= 4) &&
      Math.floor(this.elapsed / 6) > Math.floor((this.elapsed - dt) / 6)
    ) {
      for (let i = 0; i < Math.min(14, allies.length); i++) {
        const target = allies[Math.floor(Math.random() * allies.length)];
        this.fire(
          {
            ...enemies[0],
            x: i % 2 ? 750 : -750,
            z: -1000,
            damage: 19,
            heavy: false,
          },
          target,
        );
      }
      this.texts.push({
        x: this.player.x,
        z: this.player.z - 180,
        text: "INCOMING VOLLEY",
        life: 1.4,
        color: "#d7af88",
      });
    }
    this.updateEffects(dt);
    this.updateCamera(dt);
  }
  private updateCamera(dt: number) {
    const rate = Math.min(1, dt * 2.5);
    this.cameraX +=
      ((this.overview ? 0 : this.player.x * 0.7) - this.cameraX) * rate;
    this.cameraZ +=
      ((this.overview ? 0 : this.player.z - 220) - this.cameraZ) * rate;
  }
  private updateEffects(dt: number) {
    for (const p of this.particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.z += p.vz * dt;
      p.y += p.vy * dt;
      p.vy -= 380 * dt;
      if (p.y < 0) {
        p.y = 0;
        p.vy *= -0.2;
        p.vx *= 0.8;
        p.vz *= 0.8;
      }
    }
    this.particles = this.particles.filter((p) => p.life > 0).slice(-900);
    for (const p of this.debris) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.z += p.vz * dt;
      p.y += p.vy * dt;
      p.vy -= 320 * dt;
      p.angle += p.spin * dt;
      if (p.y < 0) {
        p.y = 0;
        p.vy *= -0.2;
        p.vx *= 0.8;
        p.vz *= 0.8;
        p.spin *= 0.8;
      }
    }
    this.debris = this.debris.filter((p) => p.life > 0);
    for (const t of this.texts) t.life -= dt;
    this.texts = this.texts.filter((t) => t.life > 0);
  }
  project(x: number, z: number, y = 0) {
    const s = this.zoom * (this.overview ? 0.7 : 1);
    return {
      x: this.width * 0.5 + (x - this.cameraX) * s,
      y: this.height * 0.46 + (z - this.cameraZ) * s * 0.72 - y * s,
      s,
    };
  }
  draw() {
    const g = this.ctx,
      w = this.width,
      h = this.height;
    g.fillStyle = "#1a201b";
    g.fillRect(0, 0, w, h);
    if (!this.ready || !this.ground) return;
    g.save();
    if (this.save.settings.shake && this.shake)
      g.translate(
        (Math.random() - 0.5) * this.shake,
        (Math.random() - 0.5) * this.shake,
      );
    g.imageSmoothingEnabled = false;
    const p = this.project(-1600, -1600),
      q = this.project(1600, 1600);
    g.drawImage(this.ground, p.x, p.y, q.x - p.x, q.y - p.y);
    g.fillStyle = ["#101a152b", "#14263a16", "#08271c22", "#310d0722"][
      this.territory.biome
    ];
    g.fillRect(0, 0, w, h);
    for (const stain of this.stains) {
      const p = this.project(stain.x, stain.z);
      g.fillStyle = "#50181cc0";
      g.beginPath();
      g.ellipse(p.x, p.y, stain.r * p.s, stain.r * p.s * 0.65, 0, 0, 7);
      g.fill();
    }
    // Bodies first, then standing figures sorted by their ground position.
    const sorted = [...this.units].sort(
      (a, b) => Number(a.hp > 0) - Number(b.hp > 0) || a.z - b.z,
    );
    for (const u of sorted) this.drawUnit(u);
    for (const a of this.arrows) {
      const p = this.project(a.x, a.z, a.y),
        tail = this.project(a.x - a.vx * 0.025, a.z - a.vz * 0.025, a.y - 4);
      g.strokeStyle = "#ddc797";
      g.lineWidth = Math.max(1, p.s * 1.5);
      g.beginPath();
      g.moveTo(tail.x, tail.y);
      g.lineTo(p.x, p.y);
      g.stroke();
    }
    for (const d of this.debris) {
      const p = this.project(d.x, d.z, d.y);
      g.save();
      g.translate(p.x, p.y);
      g.rotate(d.angle);
      g.globalAlpha = Math.min(1, d.life);
      g.drawImage(
        this.frames[d.type][d.team * 32],
        33,
        7,
        25,
        23,
        -8 * p.s,
        -8 * p.s,
        16 * p.s,
        16 * p.s,
      );
      g.restore();
    }
    for (const particle of this.particles) {
      const p = this.project(particle.x, particle.z, particle.y);
      g.fillStyle = particle.color;
      g.globalAlpha = Math.min(1, particle.life * 3);
      g.fillRect(
        Math.round(p.x),
        Math.round(p.y),
        Math.max(1, particle.size * p.s),
        Math.max(1, particle.size * p.s),
      );
    }
    g.globalAlpha = 1;
    for (const t of this.texts) {
      const p = this.project(t.x, t.z, 65 + (1 - t.life) * 15);
      g.globalAlpha = Math.min(1, t.life * 3);
      g.font = `bold ${t.text.length > 4 ? 13 : 11}px Inter, sans-serif`;
      g.textAlign = "center";
      g.fillStyle = "#080a08";
      g.fillText(t.text, p.x + 1, p.y + 1);
      g.fillStyle = t.color;
      g.fillText(t.text, p.x, p.y);
    }
    g.globalAlpha = 1;
    const vignette = g.createRadialGradient(
      w / 2,
      h / 2,
      h * 0.3,
      w / 2,
      h / 2,
      w * 0.7,
    );
    vignette.addColorStop(0, "transparent");
    vignette.addColorStop(1, "#060b0a88");
    g.fillStyle = vignette;
    g.fillRect(0, 0, w, h);
    g.restore();
    this.drawMinimap();
    if (this.elapsed - this.hudAt > 0.12 || !this.active) {
      this.hudAt = this.elapsed;
      this.updateHud();
    }
  }
  private drawUnit(u: Unit) {
    const g = this.ctx,
      p = this.project(u.x, u.z);
    if (
      p.x < -90 ||
      p.x > this.width + 90 ||
      p.y < -90 ||
      p.y > this.height + 100
    )
      return;
    const dead = u.hp <= 0,
      attacking = u.attack > 0;
    let row = 0,
      frame = 0;
    if (dead) {
      row = 3;
      frame = animationFrame(u.dead / 1.05);
    } else if (attacking) {
      row = u.heavy ? 2 : 1;
      frame = animationFrame(1 - u.attack / u.attackMax);
    } else if (u.moving) frame = Math.floor(u.phase) % 8;
    // Weapon family selects a matching full-body animation, including bows and spear thrusts.
    const type = attackType(u.weapon);
    const sprite = this.frames[type][(row + u.team * 4) * 8 + frame];
    const size = (u.player ? 80 : 65) * p.s,
      foot = size * 0.85;
    g.save();
    g.translate(p.x, p.y);
    g.fillStyle = "#0005";
    g.beginPath();
    g.ellipse(0, 0, 13 * p.s, 7 * p.s, 0, 0, 7);
    g.fill();
    if (u.player && !dead) {
      g.strokeStyle = "#f5d486";
      g.lineWidth = 2;
      g.beginPath();
      g.ellipse(0, 0, 20 * p.s, 13 * p.s, 0, 0, 7);
      g.stroke();
      g.fillStyle = "#eed494";
      g.beginPath();
      g.moveTo(-4, -size - 11);
      g.lineTo(4, -size - 11);
      g.lineTo(0, -size - 5);
      g.fill();
    }
    if (u.dodge > 0) g.globalAlpha = 0.65;
    if (u.stun > 0.05) g.translate(Math.sin(u.stun * 60) * 2, 0);
    g.drawImage(sprite, -size / 2, -foot, size, size);
    if (u.block) {
      g.strokeStyle = "#bbddcf";
      g.lineWidth = 2;
      g.beginPath();
      g.arc(0, -size * 0.38, size * 0.33, 3.5, 5.9);
      g.stroke();
    }
    if (!dead && (u.player || (u.hp < u.max && p.s > 0.68))) {
      g.fillStyle = "#191c18";
      g.fillRect(-15 * p.s, -size - 2, 30 * p.s, 2);
      g.fillStyle = u.team ? "#b16c58" : "#98b6a0";
      g.fillRect(-15 * p.s, -size - 2, (30 * p.s * u.hp) / u.max, 2);
    }
    if (u.player && !dead) {
      g.fillStyle = "#ffe2a2";
      g.font = "bold 10px Inter";
      g.textAlign = "center";
      g.fillText("YOU", 0, -size - 16);
    }
    g.restore();
  }
  private drawMinimap() {
    const g = this.ctx,
      mw = 136,
      mh = 100,
      left = this.width - mw - 20,
      top = 95;
    g.fillStyle = "#0c1412c9";
    g.fillRect(left, top, mw, mh);
    g.strokeStyle = "#c3ac6e55";
    g.strokeRect(left, top, mw, mh);
    for (const u of this.units)
      if (u.hp > 0) {
        g.fillStyle = u.player ? "#ffdf8e" : u.team ? "#bf7161" : "#91b69d";
        const x = left + mw / 2 + (u.x / 3000) * mw,
          z = top + mh / 2 + (u.z / 3000) * mh;
        g.fillRect(x, z, u.player ? 4 : 1.5, u.player ? 4 : 1.5);
      }
  }
  private updateHud() {
    const hp = document.querySelector<HTMLElement>("#hp-fill"),
      st = document.querySelector<HTMLElement>("#stamina-fill");
    if (hp) hp.style.width = `${(this.player.hp / this.player.max) * 100}%`;
    if (st) st.style.width = `${this.stamina}%`;
    const allies = this.units.filter((u) => !u.team && u.hp > 0).length,
      enemies = this.units.filter((u) => u.team && u.hp > 0).length;
    const count = document.querySelector("#battle-count");
    if (count) count.textContent = `${allies} / ${enemies}`;
    const msg = document.querySelector("#battle-message");
    if (msg)
      msg.textContent =
        this.charge > 0
          ? `ARMIES CHARGING · ${Math.ceil(this.charge)}`
          : this.player.hp <= 0
            ? "YOUR BANNER HAS FALLEN"
            : this.active
              ? "LEAD YOUR CLAN"
              : "THE FIELD IS YOURS";
    const status = document.querySelector("#battle-status");
    if (status)
      status.textContent = `${Math.round(this.fps)} FPS · ${this.units.length} DEPLOYED · ${this.overview ? "ARMY OVERVIEW" : "LEADER CAMERA"}`;
  }
  loop(t: number) {
    if (!this.canvas.isConnected) return;
    const raw = (t - this.last) / 1000 || 0.016;
    this.last = t;
    this.fps += (Math.min(144, 1 / raw) - this.fps) * 0.05;
    const dt = Math.min(0.04, raw);
    if (this.ready && !this.paused) {
      if (this.active) {
        if (this.hitstop > 0) this.hitstop -= dt;
        else this.update(dt);
      } else {
        for (const u of this.units) if (u.hp <= 0) u.dead += dt;
        this.updateEffects(dt);
      }
    }
    this.draw();
    this.raf = requestAnimationFrame((next) => this.loop(next));
  }
  destroy() {
    this.active = false;
    cancelAnimationFrame(this.raf);
    clearTimeout(this.endTimer);
    this.cleanup.forEach((fn) => fn());
    void this.audio?.close();
  }
}
