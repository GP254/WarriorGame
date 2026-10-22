import "./style.css";
import {
  classes,
  families,
  weapons,
  armors,
  territories,
  loadSave,
  canConquer,
  buyWeapon,
  claimVictory,
  type Family,
} from "./data";
import { Battle, type BattleResult } from "./battle";
const app = document.querySelector<HTMLDivElement>("#app")!;
let state = loadSave(),
  selected = 1,
  screen = "map",
  modal = "",
  squad = 0,
  family: Family = "swords",
  weaponId = "swords-0",
  onlyOwned = false,
  formation = "balanced",
  battle: Battle | null = null,
  saveWarning = false;
let deployment = [...state.squads];
const fmt = (n: number) => n.toLocaleString("en-US");
const paths: Record<string, string> = {
  banner: "M5 21V3m0 1h13l-3 5 3 5H5m4-9v8",
  sword: "m4 20 4-4m-3-3 6 6M8 15 18 3h3v3L10 17M14 6l4 4",
  axes: "m5 21 12-15M12 4l7-1 2 7-6 3-6-6z",
  spears: "M4 21 17 7m-2-1 6-4-2 7-4-3",
  bows: "M5 3q22 9 0 18L9 12 5 3m4 9h12m-3-3 3 3-3 3",
  shield: "M12 3 3 6v7c1 5 9 9 9 9s8-4 9-9V6l-9-3zm0 0v17",
  map: "m2 5 6-3 8 3 6-3v17l-6 3-8-3-6 3V5zm6-3v17m8-14v17",
  clan: "M8 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm9-1a3 3 0 1 0 0-6M1 21v-3c0-5 14-5 14 0v3m3-7c4 0 5 2 5 6",
  coin: "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4v12m4-10h-5a2 2 0 0 0 0 4h2a2 2 0 0 1 0 4H8",
  wood: "m12 2-6 7h3l-5 6h6v6h4v-6h6l-5-6h3l-6-7",
  iron: "m3 17 4-10 6-4 7 7 2 7-10 5-9-5zm4-10 5 6 8-3m-8 3v9",
  book: "M3 3h7l2 2 2-2h7v17h-7l-2 2-2-2H3V3zm9 2v17",
  gear: "m9 3 1-2h4l1 2 3 1 2-1 2 4-2 2v5l2 2-2 4-2-1-3 1-1 2h-4l-1-2-3-1-2 1-2-4 2-2V9L2 7l2-4 2 1 3-1zm3 5a4 4 0 1 0 0 8 4 4 0 0 0 0-8",
  arrow: "M4 12h16m-6-6 6 6-6 6",
  lock: "M6 10V7a6 6 0 0 1 12 0v3M4 10h16v12H4V10zm8 4v4",
  check: "m4 12 5 5L20 6",
  close: "m5 5 14 14M5 19 19 5",
  sun: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8m0-7v3m0 16v3M1 12h3m16 0h3M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2",
  home: "m2 11 10-9 10 9M5 9v12h14V9m-10 12v-8h6v8",
  compass: "m12 2 3 7 7 3-7 3-3 7-3-7-7-3 7-3 3-7",
  volume: "M3 9h4l6-5v16l-6-5H3V9zm14-2c4 3 4 7 0 10m3-13c7 5 7 11 0 16",
  heart: "M12 21 3 12C-3 3 8-2 12 6c4-8 15-3 9 6l-9 9",
  plus: "M12 4v16M4 12h16",
  minus: "M4 12h16",
  tower: "M4 3h4v4h3V3h3v4h3V3h4v8l-3 2v9H7v-9l-3-2V3z",
  flag: "M5 22V3h14l-4 5 4 5H5",
  eye: "M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zm10-3a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
};
const icon = (name: string, size = 20) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[name] || paths.sword}"/></svg>`;
const weaponArt = (id: string, large = false) => {
  const w = weapons.find((w) => w.id === id)!;
  return `<div class="weapon-art ${large ? "large" : ""}" style="background-image:url('/assets/${w.family}.png');background-position:${((w.index % 10) / 9) * 100}% ${(Math.floor(w.index / 10) / 4) * 100}%"></div>`;
};
const portrait = (i: number, cl = "") =>
  `<div class="portrait ${cl}" style="--col:${i};background-image:url('/assets/${["ironward", "ravager", "pikewarden", "duskranger"][i]}-v2.png')"></div>`;
function persist() {
  try {
    localStorage.setItem("ashen-banner-v2", JSON.stringify(state));
  } catch {
    if (!saveWarning) {
      saveWarning = true;
      toast("Browser storage is unavailable. Progress lasts for this session.");
    }
  }
  updateResources();
}
function toast(text: string) {
  document.querySelector(".toast")?.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.setAttribute("role", "status");
  el.textContent = text;
  document.body.append(el);
  setTimeout(() => el.remove(), 3200);
}
function updateResources() {
  const r = document.querySelector("#resources");
  if (r)
    r.innerHTML = `<span class="gold">${icon("coin")}<b>${fmt(state.gold)}</b></span><span>${icon("wood")}<b>${fmt(state.wood)}</b></span><span>${icon("iron")}<b>${fmt(state.iron)}</b></span>`;
}
function shell() {
  app.innerHTML = `<header class="topbar"><button class="brand" data-action="title" aria-label="Ashen Banner title screen"><span class="brand-mark">${icon("banner", 31)}</span><span>ASHEN <b>BANNER</b><small>A CLAN. A BANNER. A LEGACY.</small></span></button><nav aria-label="Main navigation"><button class="active" data-action="map" aria-label="Campaign">${icon("map")}<span>CAMPAIGN</span></button><button data-action="clan" aria-label="Your clan">${icon("clan")}<span>YOUR CLAN</span></button><button data-action="armory" aria-label="Armory">${icon("sword")}<span>ARMORY</span></button><button data-action="codex" aria-label="Codex">${icon("book")}<span>CODEX</span></button></nav><div id="resources"></div><button class="square settings" data-action="settings" aria-label="Settings">${icon("gear")}</button></header><main id="scene"></main><div id="modal-root"></div><footer class="statusbar"><span><i class="live-dot"></i> LOCAL CAMPAIGN <em>·</em> Progress saved automatically</span><span>ASHEN BANNER <em>/</em> MASS BATTLE BUILD 0.2</span></footer>`;
  updateResources();
}
let zoom = 1,
  panX = 0,
  panY = 0,
  base = 1;
function renderMap(reset = false) {
  screen = "map";
  battle?.destroy();
  battle = null;
  shell();
  const scene = document.querySelector<HTMLElement>("#scene")!;
  scene.innerHTML = `<div id="map-viewport" aria-label="Conquest map. Drag to explore and scroll to zoom."><div id="map-world"><img class="terrain" src="/assets/world.png" alt="The shattered frontier, from autumn forests to snowbound mountains and the ashlands" draggable="false"/><svg class="routes" viewBox="0 0 2100 1400">${territories.flatMap((t) => t.links.filter((n) => n > t.id).map((n) => `<line x1="${t.x * 21}" y1="${t.y * 14}" x2="${territories[n].x * 21}" y2="${territories[n].y * 14}" class="${state.owned.includes(t.id) || state.owned.includes(n) ? "open" : ""}"/>`)).join("")}${state.owned.map((id) => `<ellipse class="owned-land" cx="${territories[id].x * 21}" cy="${territories[id].y * 14}" rx="125" ry="85"/>`).join("")}</svg><span class="region-name north" >THE FROSTBOUND REACH</span><span class="region-name sea">THE SUNDERED SEA</span><span class="region-name marsh">THE HOLLOW MARCHES</span>${territories
    .map((t) => {
      const owned = state.owned.includes(t.id),
        open = canConquer(state, t.id);
      return `<button class="map-node ${owned ? "owned" : open ? "available" : "locked"} ${selected === t.id ? "selected" : ""}" data-territory="${t.id}" style="left:${t.x}%;top:${t.y}%" aria-label="${t.name}, ${owned ? "owned" : open ? "available to conquer" : "locked"}"><span class="node-top">${owned ? icon("flag", 14) : icon(t.wood > t.iron ? "wood" : "iron", 14)} ${owned ? "YOUR LAND" : t.wood > t.iron ? `${t.wood} TIMBER` : `${t.iron} IRON`}</span><span class="node-marker">${icon(owned ? "banner" : open ? "sword" : "lock", 20)}</span><span class="node-label">${t.name}</span>${open ? '<small class="node-status">READY TO CONQUER</small>' : ""}</button>`;
    })
    .join(
      "",
    )}</div></div><div class="map-shade"></div><section class="campaign-heading"><div class="eyebrow">CHAPTER I <span>—</span> THE SHATTERED FRONTIER</div><h1>A land without a king.</h1><p>Make it a land under your banner.</p></section><aside class="journey panel"><div class="eyebrow">YOUR CAMPAIGN</div><div class="journey-title">${icon("banner", 29)}<div><h3>The Ashen Clan</h3><span>${state.owned.length < 5 ? "A rising banner" : state.owned.length < 12 ? "Lords of the frontier" : "A kingdom in the making"}</span></div></div><div class="rule"></div><div class="spread"><span>Territories held</span><b>${state.owned.length}<small> / 16</small></b></div><div class="progress"><i style="width:${(state.owned.length / 16) * 100}%"></i></div><div class="spread muted"><span>${icon("sun", 14)} Day ${state.day}</span><span>${state.wins} victories</span></div><div class="objective"><span class="diamond">◇</span><div><strong>${state.owned.length === 16 ? "A frontier united" : "Raise your banner"}</strong><p>${state.owned.length === 16 ? "Every territory belongs to your clan." : "Conquer neighboring lands to open new paths across the frontier."}</p></div></div><button class="text-button" data-action="codex">THE STORY SO FAR ${icon("arrow", 15)}</button></aside><div class="map-legend"><span><i class="legend-dot owned"></i> Your territory</span><span><i class="legend-dot available"></i> Conquerable</span><span><i class="legend-dot locked"></i> Uncharted</span></div><div class="compass"><span>N</span>${icon("compass", 56)}</div><div class="map-controls"><button data-action="zoom-in" aria-label="Zoom in">${icon("plus")}</button><button data-action="zoom-out" aria-label="Zoom out">${icon("minus")}</button><button data-action="recenter" aria-label="Center map">${icon("compass")}</button><span id="zoom-label">100%</span></div><div class="map-hint">DRAG TO EXPLORE <span>·</span> SCROLL TO ZOOM</div><div id="territory-card"></div><div class="clan-dock panel"><div class="dock-label"><span class="eyebrow">YOUR WAR BAND</span><strong>${state.squads.reduce((a, b) => a + b, 0) + 1} <small>warriors ready</small></strong></div><div class="dock-squads">${classes.map((c, i) => `<button data-squad="${i}" class="dock-squad">${portrait(i)}<span><b>${c.name}</b><small>${state.squads[i]} warriors ${state.leader === i ? "· LEADER" : ""}</small></span></button>`).join("")}</div><button class="subtle" data-action="clan">MANAGE CLAN ${icon("arrow", 15)}</button></div>`;
  if (reset) {
    zoom = 1;
    panX = 0;
    panY = 0;
  }
  base = Math.max(scene.clientWidth / 2100, scene.clientHeight / 1400) * 1.1;
  applyTransform();
  renderTerritory();
  bindMap();
}
function applyTransform() {
  const viewport = document.querySelector<HTMLElement>("#map-viewport"),
    world = document.querySelector<HTMLElement>("#map-world");
  if (!viewport || !world) return;
  const scale = base * zoom;
  const w = 2100 * scale,
    h = 1400 * scale;
  panX = Math.max(
    -Math.max(0, (w - viewport.clientWidth) / 2),
    Math.min(Math.max(0, (w - viewport.clientWidth) / 2), panX),
  );
  panY = Math.max(
    -Math.max(0, (h - viewport.clientHeight) / 2),
    Math.min(Math.max(0, (h - viewport.clientHeight) / 2), panY),
  );
  world.style.transform = `translate(calc(-50% + ${panX}px),calc(-50% + ${panY}px)) scale(${scale})`;
  world.style.setProperty("--inverse", String(1 / scale));
  const label = document.querySelector("#zoom-label");
  if (label) label.textContent = `${Math.round(zoom * 100)}%`;
}
function bindMap() {
  const viewport = document.querySelector<HTMLElement>("#map-viewport")!;
  let drag = false,
    lastX = 0,
    lastY = 0,
    travel = 0;
  viewport.addEventListener("pointerdown", (e) => {
    if ((e.target as HTMLElement).closest("button")) return;
    drag = true;
    lastX = e.clientX;
    lastY = e.clientY;
    travel = 0;
    viewport.setPointerCapture(e.pointerId);
    viewport.classList.add("dragging");
  });
  viewport.addEventListener("pointermove", (e) => {
    if (!drag) return;
    const dx = e.clientX - lastX,
      dy = e.clientY - lastY;
    travel += Math.abs(dx) + Math.abs(dy);
    panX += dx;
    panY += dy;
    lastX = e.clientX;
    lastY = e.clientY;
    applyTransform();
  });
  viewport.addEventListener("pointerup", () => {
    drag = false;
    viewport.classList.remove("dragging");
  });
  viewport.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      zoom = Math.max(0.92, Math.min(2.8, zoom - e.deltaY * 0.001));
      applyTransform();
    },
    { passive: false },
  );
  void travel;
}
function renderTerritory() {
  const t = territories[selected],
    owned = state.owned.includes(t.id),
    open = canConquer(state, t.id);
  const el = document.querySelector("#territory-card");
  if (!el) return;
  el.innerHTML = `<aside class="territory panel"><div class="territory-art" style="background-position:${(t.biome % 2) * 100}% ${Math.floor(t.biome / 2) * 100}%"><span class="location-badge">${icon(t.type.includes("fortress") ? "tower" : "home", 13)} ${t.type}</span><span class="level-badge">${t.level ? "LV. " + t.level : "HOME"}</span><div class="art-gradient"></div></div><div class="territory-content"><div class="eyebrow ${owned ? "green" : ""}">${owned ? "UNDER YOUR BANNER" : open ? "A NEW CONQUEST AWAITS" : "BEYOND YOUR FRONTIER"}</div><h2>${t.name}</h2><p>${t.desc}</p>${!owned ? `<div class="enemy-info">${icon("clan", 17)} <span>Enemy warband</span><b>${t.enemies} warriors</b></div><div class="reward-label">SPOILS OF VICTORY</div><div class="reward-row"><span>${icon("coin")}<strong>${t.gold}</strong><small>Gold</small></span><span>${icon("wood")}<strong>${t.wood}</strong><small>Timber</small></span><span>${icon("iron")}<strong>${t.iron}</strong><small>Iron</small></span></div><button class="primary full" data-action="deploy" ${open ? "" : "disabled"}>${icon(open ? "sword" : "lock", 18)} ${open ? "PREPARE CONQUEST" : "CONQUER A NEIGHBOR FIRST"} ${open ? icon("arrow", 17) : ""}</button><div class="territory-note">${open ? "Lead your warriors. Fight alongside them." : "Expand from Hearthhold to reach this land."}</div>` : `<div class="owned-message">${icon("check", 22)} This land belongs to the Ashen Clan.</div><button class="primary full" data-action="clan">${icon("clan", 18)} PREPARE YOUR WAR BAND</button>`}</div></aside>`;
  document
    .querySelectorAll<HTMLElement>(".map-node")
    .forEach((n) =>
      n.classList.toggle("selected", Number(n.dataset.territory) === selected),
    );
}
let lastFocus: HTMLElement | null = null;
function openModal(name: string) {
  if (name === "deploy") deployment = [...state.squads];
  if (!modal) lastFocus = document.activeElement as HTMLElement;
  modal = name;
  renderModal();
}
function closeModal() {
  const action = lastFocus?.dataset.action;
  modal = "";
  renderMap();
  if (action)
    document
      .querySelector<HTMLButtonElement>(`[data-action="${action}"]`)
      ?.focus();
}
function modalFrame(
  title: string,
  kicker: string,
  content: string,
  wide = false,
) {
  document.querySelector("#modal-root")!.innerHTML =
    `<div class="modal-shade"><section class="modal ${wide ? "wide" : ""}" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div class="modal-top"><div><div class="eyebrow">${kicker}</div><h2 id="modal-title">${title}</h2></div><button class="square" data-action="close" aria-label="Close dialog">${icon("close")}</button></div>${content}</section></div>`;
  document.querySelector<HTMLButtonElement>(".modal button")?.focus();
}
function renderModal() {
  const scrollTargets = [".weapon-grid", ".weapon-detail"];
  const positions = scrollTargets.map(
    (selector) => document.querySelector(selector)?.scrollTop || 0,
  );
  if (modal === "clan") {
    const c = classes[squad],
      w = weapons.find((w) => w.id === state.equipped[squad])!,
      a = armors[state.armor[squad]];
    modalFrame(
      "A clan worth fighting for.",
      "THE ASHEN CLAN",
      `<div class="clan-layout"><div class="squad-list">${classes.map((c, i) => `<button class="squad-choice ${squad === i ? "selected" : ""}" data-squad="${i}">${portrait(i)}<span><b>${c.name}</b><small>${c.role}</small><em>${state.squads[i]} warriors</em></span>${state.leader === i ? icon("banner", 18) : ""}</button>`).join("")}<div class="small-note">Your leader joins the selected class.<br>Choose a squad to outfit its warriors.</div></div><div class="warrior-preview">${portrait(squad, "full-warrior")}<div class="warrior-glow"></div><span>${state.leader === squad ? "CLAN LEADER" : "WARRIOR CLASS"}</span><h2>${c.name}</h2><button class="subtle" data-action="leader" ${state.leader === squad ? "disabled" : ""}>${icon("banner", 16)} ${state.leader === squad ? "YOUR CHOSEN CLASS" : "LEAD AS " + c.name.toUpperCase()}</button></div><div class="equipment"><div class="eyebrow">${c.role}</div><h3>${c.name}</h3><p>${c.desc}</p><div class="stats"><span>${icon("heart")}<b>${c.hp + a.hp}</b><small>Health</small></span><span>${icon("sword")}<b>${w.damage}</b><small>Damage</small></span><span>${icon("shield")}<b>${c.def + a.def}</b><small>Armor</small></span></div><div class="equipment-label">EQUIPMENT</div><button class="equipment-slot" data-action="equip-weapon">${weaponArt(w.id)}<span><small>WEAPON</small><b>${w.name}</b><em>${w.rarity}</em></span>${icon("arrow", 16)}</button><button class="equipment-slot" data-action="armor">${icon("shield", 35)}<span><small>ARMOR</small><b>${a.name}</b><em>+${a.def} defense · ${Math.round(a.speed * 100)}% mobility</em></span>${icon("arrow", 16)}</button><div class="recruit"><div><small>SQUAD STRENGTH</small><strong>${state.squads[squad]} <span>/ 125</span></strong></div><button class="subtle" data-action="recruit" ${state.gold < 90 || state.squads[squad] >= 125 ? "disabled" : ""}>${icon("plus", 14)} RECRUIT 10 <span class="gold">90 ${icon("coin", 13)}</span></button></div><p class="small-note">Outfitting applies to the whole squad. Fallen warriors regroup after each battle.</p></div></div>`,
      true,
    );
  }
  if (modal === "armory") {
    const w = weapons.find((w) => w.id === weaponId)!;
    const list = weapons.filter(
      (w) =>
        w.family === family && (!onlyOwned || state.inventory.includes(w.id)),
    );
    const own = state.inventory.includes(w.id),
      equipped = state.equipped[squad] === w.id;
    modalFrame(
      "Steel for your story.",
      "THE ARMORY · 200 WEAPONS",
      `<div class="armory-top"><div class="tabs">${families.map((f) => `<button class="${f === family ? "active" : ""}" data-family="${f}">${icon(f === "swords" ? "sword" : f, 18)} ${f.toUpperCase()} <small>50</small></button>`).join("")}</div><button class="subtle ${onlyOwned ? "active" : ""}" data-action="owned">${icon("check", 14)} ${onlyOwned ? "OWNED ONLY" : "SHOW OWNED"}</button></div><div class="armory-layout"><div class="weapon-grid">${list.map((v) => `<button class="weapon-card tier-${v.tier} ${w.id === v.id ? "selected" : ""}" data-weapon="${v.id}" aria-label="${v.name}, ${v.cost} gold">${state.inventory.includes(v.id) ? '<span class="owned-tick">✓</span>' : ""}${weaponArt(v.id)}<b>${v.name}</b><span>${state.inventory.includes(v.id) ? "OWNED" : icon("coin", 12) + " " + fmt(v.cost)}</span></button>`).join("")}</div><aside class="weapon-detail"><div class="eyebrow rarity tier-${w.tier}">${w.rarity} ${family.slice(0, -1)}</div>${weaponArt(w.id, true)}<h3>${w.name}</h3><p>${["Reliable steel for a new beginning.", "Forged to endure the front line.", "A weapon worthy of a proven warrior.", "A fearsome heirloom of a fallen clan.", "Let its name become a legend."][w.tier]}</p><div class="detail-stat"><span>Damage</span><b>${w.damage}</b></div><div class="detail-stat"><span>Attack speed</span><b>${w.speed.toFixed(2)}×</b></div><div class="detail-stat"><span>Reach</span><b>${w.range < 150 ? "Melee · " + w.range : "Ranged · " + w.range}</b></div><div class="equipment-label">EQUIP TO SQUAD</div><div class="squad-picker">${classes.map((c, i) => `<button class="${squad === i ? "selected" : ""}" data-armory-squad="${i}" title="${c.name}">${portrait(i)}<small>${c.name}</small></button>`).join("")}</div><button class="primary full" data-action="purchase" ${equipped || (!own && state.gold < w.cost) ? "disabled" : ""}>${equipped ? icon("check", 16) + " EQUIPPED" : own ? "EQUIP TO " + classes[squad].name.toUpperCase() : icon("coin", 16) + " " + fmt(w.cost) + " · BUY & EQUIP"}</button><p class="small-note">${!own && state.gold < w.cost ? "Earn more gold by conquering territories." : "Every class can wield any weapon. Reach and attack behavior follow your choice."}</p><div class="armory-purse">${icon("coin", 17)} ${fmt(state.gold)} gold available</div></aside></div>`,
      true,
    );
  }
  if (modal === "armor")
    modalFrame(
      "Stand against the storm.",
      "ARMOR FOR " + classes[squad].name,
      `<div class="armor-grid">${armors.map((a, i) => `<button class="armor-card ${state.armor[squad] === i ? "selected" : ""}" data-armor="${i}" ${!state.armorOwned.includes(i) && (state.gold < a.cost || state.iron < a.iron || state.wood < a.wood) ? "disabled" : ""}>${portrait([3, 0, 2, 0][i])}<h3>${a.name}</h3><p>+${a.def} defense · +${a.hp} health</p><small>${Math.round(a.speed * 100)}% movement speed</small><strong>${state.armor[squad] === i ? "EQUIPPED" : state.armorOwned.includes(i) ? "EQUIP" : `${a.cost} GOLD · ${a.iron} IRON${a.wood ? " · " + a.wood + " TIMBER" : ""}`}</strong></button>`).join("")}</div><button class="text-button" data-action="clan">← BACK TO YOUR CLAN</button>`,
      true,
    );
  if (modal === "deploy") {
    const t = territories[selected];
    modalFrame(
      `The battle for ${t.name}`,
      "WAR COUNCIL",
      `<div class="deploy-banner" style="background-position:${(t.biome % 2) * 100}% ${Math.floor(t.biome / 2) * 100}%"><div><span class="eyebrow">YOUR BANNER GOES WITH YOU</span><h3>Lead from the front.</h3></div></div><div class="deploy-body"><div class="versus"><span><strong>${deployment.reduce((a, b) => a + b, 0) + 1}</strong> YOUR WARRIORS</span>${icon("sword", 28)}<span><strong>${t.enemies}</strong> ENEMY WARRIORS</span></div><div class="deployment-roster">${classes.map((c, i) => `<div class="deployment-unit">${portrait(i)}<b>${c.name}</b><small>${state.squads[i]} available</small><div><button data-deploy-step="${i}" data-step="-10" aria-label="Deploy fewer ${c.name}">−</button><strong>${deployment[i]}</strong><button data-deploy-step="${i}" data-step="10" aria-label="Deploy more ${c.name}">+</button></div></div>`).join("")}</div><div class="equipment-label">CHOOSE YOUR FORMATION</div><div class="formation-list">${[
        ["balanced", "Battle line", "A broad, balanced front."],
        ["wedge", "Spearhead", "Concentrate the charge."],
        ["shield", "Shield wall", "Infantry ahead, archers behind."],
      ]
        .map(
          ([id, n, d]) =>
            `<button data-formation="${id}" class="${formation === id ? "selected" : ""}"><span class="formation-symbol">${id === "balanced" ? "▴ ▴ ▴" : id === "wedge" ? "◁" : "▥"}</span><b>${n}</b><small>${d}</small></button>`,
        )
        .join(
          "",
        )}</div><div class="controls-guide"><span><kbd>W A S D</kbd> Move</span><span><kbd>J</kbd> Strike</span><span><kbd>K</kbd> Heavy</span><span><kbd>L</kbd> Guard</span><span><kbd>SPACE</kbd> Dodge</span><span><kbd>E</kbd> Rally</span></div><p class="small-note">Deploy up to 500 warriors together. The opening charge is automatic. When the lines meet, take control of your leader. Scroll to zoom. Tab switches between the high rear camera and army overview.</p><div class="deploy-actions"><button class="subtle" data-action="clan">${icon("clan", 17)} OUTFIT CLAN</button><button class="primary" data-action="battle">${icon("banner", 19)} RAISE YOUR BANNER ${icon("arrow", 18)}</button></div></div>`,
    );
  }
  if (modal === "codex")
    modalFrame(
      "The Shattered Frontier",
      "CHRONICLES & FIELD GUIDE",
      `<div class="codex-body"><p class="intro">No crown. No prophecy.<br>Only the people who follow you.</p><p>When the old banners fell, the frontier broke into rival clans. From the fires of Hearthhold, you will carve out a home—one village, one crossing, one battle at a time.</p><div class="codex-columns"><article><h3>Claim the frontier</h3><p>Gold markers are neighboring lands you can attack. Victory grants gold, timber, and iron, and opens new routes. All 16 territories can be united.</p><h3>Build your war band</h3><p>Recruit up to 125 warriors in each class: 500 troops plus your leader. Equip weapons for each squad; use gold, timber, and iron to unlock armor. Your chosen class determines your leader’s base stats.</p></article><article><h3>Fight with purpose</h3><p>Hold J to chain light attacks, K for a heavy attack, and L or Shift to guard. Scroll to zoom; Tab toggles the army overview. Space dodges with a brief invulnerability window. E spends stamina to rally and heal nearby allies.</p><h3>Learn and return</h3><p>A fallen leader ends the battle. Your territory and equipment remain safe. Warriors regroup, allowing you to adjust your strategy and try again.</p></article></div><div class="chronicle">${icon("banner", 26)}<span><strong>${state.owned.length} lands united · ${state.wins} battles won</strong><small>Day ${state.day} of the Ashen Clan’s journey</small></span></div></div>`,
    );
  if (modal === "settings")
    modalFrame(
      "Around the campfire",
      "GAME SETTINGS",
      `<div class="settings-body">${(["blood", "sound", "shake"] as const).map((s, i) => `<button class="setting-row" data-setting="${s}"><span><b>${["Blood & battle debris", "Combat sound", "Camera shake"][i]}</b><small>${["Pixel blood particles and ground stains.", "Steel impacts and the rally horn.", "A brief camera impact when a strike connects."][i]}</small></span><i class="toggle ${state.settings[s] ? "on" : ""}" aria-label="${state.settings[s] ? "On" : "Off"}"></i></button>`).join("")}<div class="controls-guide"><span><kbd>ESC</kbd> Pause / close</span><span><kbd>WASD</kbd> Move in battle</span></div><button class="subtle full" data-action="export">EXPORT CAMPAIGN SAVE ${icon("arrow", 16)}</button><p class="small-note">Your campaign saves on this browser. Desktop keyboard controls are recommended for combat. Touch controls are also available.</p></div>`,
    );
  scrollTargets.forEach((selector, i) => {
    const el = document.querySelector(selector);
    if (el) el.scrollTop = positions[i];
  });
}
function startBattle() {
  if (!canConquer(state, selected)) return;
  modal = "";
  screen = "battle";
  const t = territories[selected];
  app.innerHTML = `<div class="battle-scene"><canvas id="battle-canvas" aria-label="Battlefield"></canvas><div class="battle-header"><button class="subtle" data-action="pause">Ⅱ PAUSE</button><div><span class="eyebrow">THE BATTLE FOR</span><h2>${t.name}</h2></div><div class="battle-balance">${icon("banner")}<b id="battle-count"></b>${icon("sword")}</div></div><div class="battle-message" id="battle-message">ASSEMBLING YOUR WAR BAND</div><div class="battle-bottom"><div class="leader-health">${portrait(state.leader)}<div><span class="eyebrow">CLAN LEADER</span><h3>${classes[state.leader].name}</h3><div class="health-bar"><i id="hp-fill"></i></div><div class="stamina-bar"><i id="stamina-fill"></i></div><small>HEALTH <span> / </span> STAMINA</small></div></div><div class="combat-buttons"><button data-combat="slash">${icon("sword", 25)}<b>STRIKE</b><kbd>J</kbd></button><button data-combat="heavy">${icon("axes", 25)}<b>HEAVY</b><kbd>K</kbd></button><button data-combat="guard">${icon("shield", 25)}<b>GUARD</b><kbd>L</kbd></button><button data-combat="dodge">${icon("arrow", 25)}<b>DODGE</b><kbd>SPACE</kbd></button><button data-combat="rally">${icon("banner", 25)}<b>RALLY</b><kbd>E</kbd></button></div></div><div class="battle-view"><button class="subtle" data-action="overview">TAB · ARMY VIEW</button><small id="battle-status"></small></div><div class="move-help"><kbd>W A S D</kbd> MOVE · HOLD J STRIKE · SCROLL ZOOM</div><div class="touch-move"><button data-move="KeyW">↑</button><button data-move="KeyA">←</button><button data-move="KeyS">↓</button><button data-move="KeyD">→</button></div><div id="pause-panel" class="modal-shade hidden"><section class="pause-card panel"><div class="eyebrow">THE BATTLE WAITS</div><h2>Hold your ground.</h2><button class="primary full" data-action="resume">RESUME BATTLE</button><button class="subtle full" data-action="retreat">RETREAT TO THE MAP</button><p class="small-note">Retreating forfeits the battle rewards.</p></section></div></div>`;
  battle = new Battle(
    document.querySelector("#battle-canvas")!,
    state,
    t,
    endBattle,
    formation,
    deployment,
  );

  document.querySelectorAll<HTMLButtonElement>("[data-move]").forEach((b) => {
    b.onpointerdown = (e) => {
      e.preventDefault();
      b.setPointerCapture(e.pointerId);
      battle?.keys.add(b.dataset.move!);
    };
    b.onpointerup = () => battle?.keys.delete(b.dataset.move!);
    b.onpointercancel = () => battle?.keys.delete(b.dataset.move!);
  });
  const guard = document.querySelector<HTMLButtonElement>(
    '[data-combat="guard"]',
  )!;
  guard.onpointerdown = (e) => {
    e.preventDefault();
    guard.setPointerCapture(e.pointerId);
    battle?.action("guard");
  };
  guard.onpointerup = () => battle?.keys.delete("KeyL");
  guard.onpointercancel = () => battle?.keys.delete("KeyL");
}
function endBattle(r: BattleResult) {
  const t = territories[selected];
  if (r.win) claimVictory(state, t.id);
  persist();
  const reward = r.win
    ? `<div class="result-rewards"><span>${icon("coin")} +${t.gold}</span><span>${icon("wood")} +${t.wood}</span><span>${icon("iron")} +${t.iron}</span></div>`
    : "";
  const overlay = document.createElement("div");
  overlay.className = "modal-shade";
  overlay.innerHTML = `<section class="result panel"><span class="result-emblem">${icon(r.win ? "banner" : "shield", 55)}</span><div class="eyebrow">${r.win ? "A NEW CHAPTER IN YOUR LEGEND" : "THE CLAN WILL RISE AGAIN"}</div><h1>${r.win ? "Your banner rises." : "The line is broken."}</h1><p>${r.win ? `${t.name} now belongs to the Ashen Clan.` : "Your warriors regroup at Hearthhold. Refit your clan and return."}</p>${reward}<div class="result-stats"><span><b>${r.kills}</b>Personal kills</span><span><b>${r.survivors}</b>Survivors</span><span><b>${r.seconds}s</b>Battle time</span></div><button class="primary full" data-action="map">${r.win ? "CONTINUE YOUR CONQUEST" : "RETURN TO THE MAP"} ${icon("arrow")}</button></section>`;
  app.append(overlay);
}
function titleScreen() {
  screen = "title";
  battle?.destroy();
  battle = null;
  app.innerHTML = `<div class="title-screen"><div class="title-vignette"></div><div class="title-content"><span class="title-emblem">${icon("banner", 66)}</span><div class="eyebrow">LEAD YOUR CLAN. WRITE YOUR LEGEND.</div><h1>ASHEN<br><span>BANNER</span></h1><p>A fractured land. A fierce new beginning.</p><button class="primary" data-action="start">${state.wins ? "CONTINUE CAMPAIGN" : "BEGIN YOUR CONQUEST"} ${icon("arrow")}</button><small>A FICTIONAL WORLD · A SINGLE-PLAYER CONQUEST</small></div><span class="title-version">MASS BATTLE BUILD · 0.2</span></div>`;
}
app.addEventListener("click", (e) => {
  const b = (e.target as HTMLElement).closest<HTMLElement>("button");
  if (!b || b.hasAttribute("disabled")) return;
  if (b.dataset.territory) {
    selected = +b.dataset.territory;
    renderTerritory();
    return;
  }
  if (b.dataset.squad) {
    squad = +b.dataset.squad;
    openModal("clan");
    return;
  }
  if (b.dataset.deployStep !== undefined) {
    const i = +b.dataset.deployStep;
    deployment[i] = Math.max(
      0,
      Math.min(state.squads[i], deployment[i] + Number(b.dataset.step)),
    );
    renderModal();
    return;
  }
  if (b.dataset.family) {
    family = b.dataset.family as Family;
    weaponId = weapons.find(
      (w) =>
        w.family === family && (!onlyOwned || state.inventory.includes(w.id)),
    )!.id;
    renderModal();
    return;
  }
  if (b.dataset.weapon) {
    weaponId = b.dataset.weapon;
    renderModal();
    return;
  }
  if (b.dataset.armorySquad) {
    squad = +b.dataset.armorySquad;
    renderModal();
    return;
  }
  if (b.dataset.formation) {
    formation = b.dataset.formation;
    renderModal();
    return;
  }
  if (b.dataset.setting) {
    const k = b.dataset.setting as keyof typeof state.settings;
    state.settings[k] = !state.settings[k];
    persist();
    renderModal();
    return;
  }
  if (b.dataset.armor) {
    const i = +b.dataset.armor,
      a = armors[i];
    if (!state.armorOwned.includes(i)) {
      if (state.gold < a.cost || state.wood < a.wood || state.iron < a.iron)
        return;
      state.gold -= a.cost;
      state.wood -= a.wood;
      state.iron -= a.iron;
      state.armorOwned.push(i);
    }
    state.armor[squad] = i;
    persist();
    renderModal();
    toast(`${a.name} equipped to ${classes[squad].name}.`);
    return;
  }
  if (b.dataset.combat) {
    if (b.dataset.combat !== "guard") battle?.action(b.dataset.combat);
    return;
  }
  switch (b.dataset.action) {
    case "title":
      titleScreen();
      break;
    case "start":
      renderMap(true);
      break;
    case "map":
      modal = "";
      renderMap();
      break;
    case "clan":
    case "codex":
    case "settings":
    case "deploy":
    case "armor":
      openModal(b.dataset.action);
      break;
    case "armory":
      family = "swords";
      weaponId = state.equipped[squad];
      family = weapons.find((w) => w.id === weaponId)!.family;
      openModal("armory");
      break;
    case "equip-weapon":
      weaponId = state.equipped[squad];
      family = weapons.find((w) => w.id === weaponId)!.family;
      openModal("armory");
      break;
    case "close":
      closeModal();
      break;
    case "zoom-in":
      zoom = Math.min(2.8, zoom + 0.2);
      applyTransform();
      break;
    case "zoom-out":
      zoom = Math.max(0.92, zoom - 0.2);
      applyTransform();
      break;
    case "recenter":
      zoom = 1;
      panX = panY = 0;
      applyTransform();
      break;
    case "leader":
      state.leader = squad;
      persist();
      renderModal();
      toast(`You will lead as an ${classes[squad].name}.`);
      break;
    case "recruit":
      if (state.gold >= 90 && state.squads[squad] < 125) {
        state.gold -= 90;
        state.squads[squad] = Math.min(125, state.squads[squad] + 10);
        persist();
        renderModal();
        toast("Reinforcements have sworn to your banner.");
      }
      break;
    case "owned":
      onlyOwned = !onlyOwned;
      renderModal();
      break;
    case "purchase":
      if (buyWeapon(state, weaponId)) {
        state.equipped[squad] = weaponId;
        persist();
        renderModal();
        toast(`Equipped to the ${classes[squad].name} squad.`);
      }
      break;
    case "overview":
      battle?.setOverview(!battle.overview);
      break;
    case "battle":
      startBattle();
      break;
    case "pause":
    case "resume":
      battle?.togglePause();
      break;
    case "retreat":
      renderMap();
      break;
    case "export": {
      const url = URL.createObjectURL(
        new Blob([JSON.stringify(state, null, 2)], {
          type: "application/json",
        }),
      );
      const a = document.createElement("a");
      a.href = url;
      a.download = "ashen-banner-save.json";
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      toast("Campaign save exported.");
      break;
    }
  }
});
window.addEventListener("keydown", (e) => {
  if (modal && e.key === "Escape") {
    e.preventDefault();
    closeModal();
  }
  if (modal && e.key === "Tab") {
    const list = Array.from(
      document.querySelectorAll<HTMLElement>(".modal button:not([disabled])"),
    );
    const first = list[0],
      last = list.at(-1);
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last?.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first?.focus();
    }
  }
});
window.addEventListener("resize", () => {
  if (screen === "map") {
    const scene = document.querySelector<HTMLElement>("#scene")!;
    base = Math.max(scene.clientWidth / 2100, scene.clientHeight / 1400) * 1.1;
    applyTransform();
  }
});
// First arrival opens directly onto the campaign; the crest returns to the title screen.
renderMap(true);
