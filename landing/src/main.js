const story = document.querySelector('.story');
const stage = document.querySelector('.stage');
const copies = [...document.querySelectorAll('.copy')];
const header = document.querySelector('header.nav');
const headerActions = header.querySelector('nav');
// Scroll distances in stage heights: linger, then scrub to the next scene.
const HOLD = 0.3;
const FIRST_HOLD = 0.08;
const TRANSITION = 0.35;
const STEP = HOLD + TRANSITION;
let frames = [];
const clamp = value => Math.max(0, Math.min(1, value));
const mix = (a, b, t) => a + (b - a) * t;
const panel = document.querySelector('.native-panel');
const panelImages = [...panel.querySelectorAll('img')];
const cue = document.querySelector('.scroll-cue');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let scheduled = false;
const computer = document.querySelector('.computer');
const phone = document.querySelector('.phone');

// One physical device on a viewport-sized stage. The camera moves it;
// no intermediate column or card crops its silhouette.
function frameScene(scene) {
  const width = stage.clientWidth;
  const height = stage.clientHeight;
  const mobile = width <= 700;
  // Follow each scene's copy instead of reserving the hero's CTA space everywhere.
  const copyBottom = Math.max(...[...copies[scene].children].map(element => element.offsetTop + element.offsetHeight));
  const visualTop = mobile ? copies[scene].parentElement.offsetTop + copyBottom + 42 : 0;
  let scale, x, y;
  if (scene <= 2) {
    scale = mobile
      ? [0.98, Math.min(0.76, width / 500), Math.min(0.82, (height - visualTop - 24) / 510)][scene]
      : [1.85, Math.min(1.25, width / 1000), Math.min(1.2, (height - 165) / 510)][scene];
    // 919 is the right edge of the MacBook display in its 1000px asset.
    const displayRight = width * (mobile ? 0.96 : scene === 0 ? 0.55 : 0.54);
    x = displayRight - 919 * scale;
    y = mobile
      ? visualTop - 27.5 * scale
      : scene === 2
        ? (height - 645 * scale) / 2 + 30
        : height * 0.27 - 27.5 * scale;
  } else {
    scale = mobile
      ? width * (scene === 3 ? 0.92 : 0.79) / 1000
      : Math.min(width * (scene === 3 ? 0.54 : 0.48) / 1000, (height - 180) / 645);
    x = width * (mobile ? 0.04 : 0.025);
    y = mobile ? visualTop + (scene === 3 ? 20 : 55) : (height - 645 * scale) / 2 + 30;
  }

  // Keep the menu readable in the close-ups, even when the mobile camera shrinks.
  const menuZoom = mobile && scene === 0 ? 1.5 : scene <= 1 ? Math.max(1.28, Math.min(2.5, 13 / (13 * 838 / 1440 * scale))) : 1.28;
  const phoneWidth = mobile ? Math.min(width * 0.35, 180, Math.max(100, height - visualTop - 24) / 2.062) : Math.min(width * 0.18, 250, (height - 180) / 2.062);
  return {x, y, scale, menuZoom, phoneWidth,
    phoneX: width * (mobile ? 0.61 : 0.39),
    phoneY: mobile ? visualTop : (height - phoneWidth * 800 / 388) / 2 + 25,
    panelWidth: scene <= 1 ? 448 * 0.85 : scene === 2 ? 292 : 256,
    panelHeight: scene <= 1 ? 236 * 0.85 : scene === 2 ? 486 : 210,
    panelTop: scene <= 1 ? 838 * 28 / 1440 * menuZoom + 13 : scene === 2 ? 29 : 130,
    visualTop,
    panelRight: scene <= 2 ? 17 : 55
  };
}
function measure() {
  frames = copies.map((_, index) => frameScene(index));
  // Keep the pinned distance in sync with the scene timing, including the last hold.
  story.style.height = `${stage.offsetHeight * (1 + FIRST_HOLD + (copies.length - 1) * STEP)}px`;
  story.style.setProperty('--scene-step', `${stage.offsetHeight * STEP}px`);
  story.style.setProperty('--first-step', `${stage.offsetHeight * (FIRST_HOLD + TRANSITION)}px`);
  update();
}

function update() {
  scheduled = false;
  if (!frames.length) return;
  const progress = Math.max(0, -story.getBoundingClientRect().top / stage.offsetHeight) + HOLD - FIRST_HOLD;
  const step = Math.min(4, Math.floor(progress / STEP));
  const fraction = clamp((progress - step * STEP - HOLD) / TRANSITION);
  const eased = fraction * fraction * (3 - 2 * fraction);
  const steppedProgress = Math.min(4, step + eased);
  const position = reducedMotion.matches ? Math.round(steppedProgress) : steppedProgress;
  const from = Math.min(3, Math.floor(position));
  const t = position - from;
  const a = frames[from], b = frames[from + 1];
  const value = key => mix(a[key], b[key], t);
  // Move the mobile content boundary continuously with the camera. Switching
  // between scene bounds at 45% made the laptop jump upward mid-transition.
  const copyFloor = stage.clientWidth <= 700 ? value('visualTop') : 0;
  const computerY = stage.clientWidth <= 700 ? Math.max(value('y'), copyFloor - 27.5 * value('scale')) : value('y');
  computer.style.transform = `translate(${value('x')}px, ${computerY}px) scale(${value('scale')})`;
  computer.style.setProperty('--menu-image-width', `${value('menuZoom') * 100}%`);
  computer.style.setProperty('--menu-height', `${838 * 28 / 1440 * value('menuZoom') + 3}px`);
  computer.style.setProperty('--menu-inset', `${18 / value('scale')}px`);
  panel.style.width = `${value('panelWidth')}px`;
  panel.style.top = `${value('panelTop')}px`;
  panel.style.right = `${value('panelRight')}px`;
  panel.style.opacity = position >= 0.5 ? 1 : 0;
  // Complete the content crossfade in time, even when scrolling stops midway.
  const panelIndex = Math.max(0, Math.min(2, Math.round(position) - 1));
  const panelAspect = [708 / 1344, 2238 / 1344, 630 / 768][panelIndex];
  panel.style.height = `${value('panelWidth') * panelAspect}px`;
  panelImages.forEach((image, index) => {
    image.style.opacity = index === panelIndex ? 1 : 0;
  });
  const phoneProgress = clamp(position - 3);
  phone.style.width = `${value('phoneWidth')}px`;
  phone.style.height = `${value('phoneWidth') * 800 / 388}px`;
  phone.style.left = `${value('phoneX')}px`;
  phone.style.top = `${Math.max(value('phoneY'), copyFloor)}px`;
  phone.style.transform = `translateX(${(1-phoneProgress)*stage.clientWidth*.45}px)`;
  phone.style.opacity = phoneProgress;
  document.querySelector('.menubar-app').style.visibility = position >= 3 ? 'visible' : 'hidden';
  const next = Math.round(position);
  stage.dataset.scene = next;
  // The header follows the same first transition, including reverse scrolling.
  const headerProgress = clamp(position);
  const brand = header.querySelector('.brand');
  const inset = getComputedStyle(header).getPropertyValue('--header-inset').trim();
  brand.style.left = `calc((100% - ${inset}) * ${1-headerProgress} + ${inset} * ${headerProgress})`;
  brand.style.transform = `translateX(${-100 * (1-headerProgress)}%)`;
  headerActions.style.opacity = headerProgress;
  headerActions.style.transform = `translateY(${-6 * (1-headerProgress)}px)`;
  headerActions.style.visibility = headerProgress > 0 ? 'visible' : 'hidden';
  headerActions.style.pointerEvents = headerProgress === 1 ? 'auto' : 'none';
  headerActions.inert = headerProgress < 1;
  headerActions.setAttribute('aria-hidden', String(headerProgress < 1));
  cue.style.opacity = 1 - headerProgress;
  cue.style.visibility = headerProgress < 1 ? 'visible' : 'hidden';
  cue.inert = headerProgress > 0;
  cue.setAttribute('aria-hidden', String(headerProgress > 0));
  // A paused scroll always leaves one readable scene, never two faded-out ones.
  copies.forEach((copy, index) => {
    const active = index === next;
    copy.style.opacity = active ? 1 : 0;
    copy.style.transform = `translateY(${active ? 0 : index < next ? -8 : 8}px)`;
    copy.classList.toggle('active', active);
    copy.setAttribute('aria-hidden', String(!active));
    copy.inert = !active;
  });
}
addEventListener('scroll', () => { if (!scheduled) { scheduled = true; requestAnimationFrame(update); } }, { passive: true });
let measurementScheduled = false;
function scheduleMeasure() {
  if (measurementScheduled) return;
  measurementScheduled = true;
  requestAnimationFrame(() => {
    measurementScheduled = false;
    measure();
  });
}
// Embedded browsers can change height without changing width. Height media
// queries also change typography, so cached camera frames must be refreshed.
addEventListener('resize', scheduleMeasure);
window.visualViewport?.addEventListener('resize', scheduleMeasure);
const layoutObserver = new ResizeObserver(scheduleMeasure);
layoutObserver.observe(stage);
layoutObserver.observe(copies[0].parentElement);
copies.forEach(copy => [...copy.children].forEach(element => layoutObserver.observe(element)));
document.fonts.ready.then(measure);
reducedMotion.addEventListener('change', update);
measure();
