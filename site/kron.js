// @ts-check
/* Ember's hero: a faithful port of Construct Design's "Kron" website hero
   (https://www.tobiadonadon.com/projects/construct/design?block=kron) from React to one plain module.
   The motion is Kron's, tuned by hand upstream: the loop, low-pass, lean, spin, flip, letter springs,
   shadow constants, pointer follow, press-spin, DPR cap, scissoring and pausing are copied line for line.
   What changed for Ember (docs/design/DIRECTION.md): the words, the colours, the display face and its
   tracking, and the form. Kron's six chrome petals became the Ember lens: a biconvex chrome disc with
   the mark's ember crescent (EmberGeometry: tilt 28°, terminator 0.42) inlaid on both faces.

   Markup (static, so the headline reads without JavaScript):
     <section class="krn-root" data-ground="#1A1512" data-ink="#EFE4D6">
       <header class="krn-nav">…</header>
       <h1 class="krn-head" aria-label="…"><span class="krn-row" data-a="spread"><span class="krn-w">YOUR</span>…
       <p class="krn-note">…</p>
       <canvas class="krn-gl" aria-hidden="true"></canvas>
     </section>
   mountKron(root) splits each word into spring letters, fits the type, and starts the form. */

export const TRACK = -0.052; // em. Kron's Inter Tight ran −0.045; SF Pro Display Bold is wider.
const LEAD = 0.8; // em, one row
export const FACE =
  'system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", Helvetica, Arial, sans-serif';

const VERT = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';
/* Kron's fragment shader. Unchanged: the raymarch, bounds, normals, the page lookup, the studio, AO,
   rim, coverage and the soft shadow. Changed: map() is the Ember lens, the crescent gets an enamel
   material, the studio is a dim warm room with one bright softbox and no rigging bars, the body is smoked chrome (a pale studio glares on Coal), and the shadow tint is a uniform (burnt Coal). */
export const FRAG = `precision highp float;
uniform vec2 uRes,uC;uniform float uR,uR0,uH;uniform mat3 uM;uniform sampler2D uPage;uniform vec3 uSh,uBurnt;
const float SAFE=.8,LA=.94,LT=.2,TERM=.42,TILT=.48869219;
const vec3 LD=vec3(-.2683,-.3578,.8944);
float smax(float a,float b,float k){float h=clamp(.5-.5*(b-a)/k,0.,1.);return mix(b,a,h)+k*h*(1.-h);}
/* biconvex lens: two spheres of radius RS whose cap meets at the rim (radius LA, half-thickness LT) */
float lens(vec3 p){
  float RS=(LA*LA+LT*LT)/(2.*LT),Z=RS-LT;
  return smax(length(p-vec3(0.,0.,Z))-RS,length(p+vec3(0.,0.,Z))-RS,.05);
}
float map(vec3 pw){vec3 p=uM*pw;return lens(p)*SAFE;}
vec3 nrm(vec3 p){vec2 e=vec2(1.,-1.)*.0018;return normalize(e.xyy*map(p+e.xyy)+e.yyx*map(p+e.yyx)+e.yxy*map(p+e.yxy)+e.xxx*map(p+e.xxx));}
/* the mark on the front face: lit between the elliptical terminator and the limb, lower right */
float crescent(vec3 o){
  if(abs(o.z)<.02)return 0.;
  if(o.z<0.)o.x=-o.x; /* the back face carries the same mark, read from behind */
  float c=cos(TILT),s=sin(TILT);
  vec2 q=vec2(c*o.x+s*o.y,c*o.y-s*o.x)/(LA*.9);
  float rr=length(q);
  float limb=1.-smoothstep(.97,1.,rr);
  float tx=TERM*sqrt(max(0.,1.-q.y*q.y));
  return limb*smoothstep(-.015,.015,q.x-tx)*step(0.,q.x);
}
vec3 page(vec2 pt){
  vec2 uv=(uC+pt*uR0)/uRes;
  vec3 c=texture2D(uPage,clamp(uv,0.,1.)).rgb;
  float o=max(max(-uv.x,uv.x-1.),max(-uv.y,uv.y-1.));
  return c*(1.-.5*smoothstep(0.,.7,o));
}
vec3 env(vec3 r,vec3 p){
  float e=r.z;
  vec3 dark=vec3(.035,.028,.024);
  vec3 sky=mix(vec3(.16,.14,.125),vec3(.80,.76,.71),smoothstep(.35,.98,e));
  sky+=vec3(1.05,1.,.94)*smoothstep(.70,.86,dot(r,vec3(-.5498,-.6198,.5598)));
  sky*=1.-.94*smoothstep(.865,.915,dot(r,vec3(.7836,.1206,.6094)));
  sky*=1.-.9*smoothstep(.935,.965,dot(r,vec3(-.2504,.7512,.6109)));
  sky=mix(dark,sky,smoothstep(.015,.17,e));
  float t=(-uH-p.z)/min(r.z,-.02);
  vec2 pt=p.xy+r.xy*t;
  vec3 pg=page(pt)*mix(.42,.96,smoothstep(.35,1.5,length(pt-vec2(.1,.13)*uH)));
  pg=mix(dark,pg,smoothstep(-.015,-.16,e));
  return e>0.?sky:pg;
}
void main(){
  vec2 pix=vec2(gl_FragCoord.x,uRes.y-gl_FragCoord.y);
  vec2 q=(pix-uC)/uR,q0=(pix-uC)/uR0;
  vec4 obj=vec4(0.);
  if(dot(q,q)<1.21){
    vec3 ro=vec3(0.,0.,5.),rd=normalize(vec3(q,-5.));
    float b=dot(ro,rd),h=b*b-(25.-1.21);
    if(h>0.){
      h=sqrt(h);float t=-b-h,t1=-b+h,md=1e3,mt=t;bool hit=false;
      for(int i=0;i<120;i++){float d=map(ro+rd*t);if(d<md){md=d;mt=t;}if(d<.0012){hit=true;break;}t+=max(d,.0024);if(t>t1)break;}
      float cov=hit?1.:1.-smoothstep(0.,1.7/uR,md);
      if(cov>0.){
        if(!hit)t=mt;
        vec3 p=ro+rd*t;
        vec3 pc=vec3(p.xy*(uR/uR0),p.z);
        vec3 n=nrm(p),r=reflect(rd,n);
        vec3 col=env(r,pc);
        float ao=clamp(map(p+n*.09)/(.09*SAFE),0.,1.);
        col*=mix(.42,1.,ao);
        col=mix(col,vec3(1.),.07*pow(1.-max(dot(n,-rd),0.),4.));
        col*=vec3(.965,.972,.985);
        /* smoked chrome: the mark is a dark disc, so the body keeps only its hottest highlights */
        col=col*vec3(.30,.27,.25)+pow(col,vec3(4.))*.7;
        /* the ember crescent: glazed enamel, hot on the middle of the limb, deep at the tips */
        float cr=crescent(uM*p);
        if(cr>0.){
          vec3 o=uM*p;if(o.z<0.)o.x=-o.x;float c=cos(TILT),s=sin(TILT);
          vec2 m=vec2(c*o.x+s*o.y,c*o.y-s*o.x)/(LA*.9);
          float hot=length(m-vec2(.92,0.));
          vec3 glaze=mix(vec3(1.,.886,.737),vec3(.8,.392,.216),smoothstep(0.,.55,hot));
          glaze=mix(glaze,vec3(.478,.165,.07),smoothstep(.55,1.25,hot));
          float fr=pow(1.-max(dot(n,-rd),0.),3.);
          col=mix(col,glaze*(.78+.22*ao)+col*.16,cr*(1.-.55*fr));
        }
        obj=vec4(col,1.)*cov;
      }
    }
  }
  float sh=0.;
  if(obj.a<.999){
    vec3 pp=vec3(q0,-uH);
    float bb=dot(pp,LD),hh=bb*bb-(dot(pp,pp)-2.4);
    if(hh>0.){
      hh=sqrt(hh);float t=max(-bb-hh,.02),t1=-bb+hh,res=1.;
      for(int i=0;i<28;i++){float d=map(pp+LD*t);res=min(res,uSh.x*d/t);if(res<0.||t>t1)break;t+=clamp(d,.025,.22);}
      sh=(1.-smoothstep(0.,1.,max(res,0.)))*uSh.y;
      sh+=uSh.z*exp(-max(map(pp),0.)*3.2/SAFE);
    }
  }
  float sa=clamp(sh,0.,.86)*(1.-obj.a);
  gl_FragColor=vec4(obj.rgb+uBurnt*sa,obj.a+sa);
}`;

/**
 * @typedef {{ el: HTMLElement; ch: string; row: number; x: number; y: number; left: number; base: number; ox: number; oy: number; or: number; vx: number; vy: number; vr: number; shown: boolean }} Letter
 * @typedef {{ pace?: number; play?: number; autoplay?: boolean }} Options
 */

/** Split every word of the headline into letters (once). Each word keeps a zero-size baseline marker. */
export function splitLetters(/** @type {HTMLElement} */ head) {
  head.querySelectorAll('.krn-w').forEach((w) => {
    if (w.querySelector('.krn-l')) return;
    const word = (w.textContent || '').trim().toUpperCase();
    w.textContent = '';
    Array.from(word).forEach((ch) => {
      const l = document.createElement('span');
      l.className = 'krn-l';
      l.textContent = ch;
      w.appendChild(l);
    });
    const bl = document.createElement('i');
    bl.className = 'krn-bl';
    w.appendChild(bl);
  });
}

/** "#1A1512" → [26, 21, 18] */
export function hexRgb(/** @type {string} */ hex) {
  const h = hex.replace('#', '');
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
}

/**
 * The page's ground, darkened toward burnt umber: the shadow's own colour, never grey.
 * Premultiplied, so this is the colour the shadow shows at full strength.
 */
export function burntTint(/** @type {string} */ ground) {
  const [r, g, b] = hexRgb(ground).map((v) => v / 255);
  return [r * 0.34 + 0.003, g * 0.19, b * 0.1];
}

/**
 * Start the hero. Returns a cleanup function.
 * @param {HTMLElement} el
 * @param {Options} [options]
 */
export function mountKron(el, options = {}) {
  const live = {
    pace: options.pace ?? 1,
    play: options.play ?? 1,
    autoplay: options.autoplay ?? true,
  };
  const ground = el.dataset.ground || '#1A1512';
  const ink = el.dataset.ink || '#EFE4D6';
  const cv = /** @type {HTMLCanvasElement} */ (el.querySelector('.krn-gl'));
  const head = /** @type {HTMLElement} */ (el.querySelector('.krn-head'));
  const nav = /** @type {HTMLElement} */ (el.querySelector('.krn-nav'));
  if (!cv || !head || !nav) return () => {};
  splitLetters(head);
  el.setAttribute('data-split', '1');
  const rowEls = Array.from(el.querySelectorAll('.krn-row')).map(
    (r) => /** @type {HTMLElement} */ (r),
  );
  const noteEl = /** @type {HTMLElement | null} */ (
    el.querySelector('.krn-note')
  );
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  let dead = false;

  /** @type {Letter[]} */
  const letters = [];
  rowEls.forEach((r, ri) => {
    r.querySelectorAll('.krn-l').forEach((n) => {
      letters.push({
        el: /** @type {HTMLElement} */ (n),
        ch: n.textContent || '',
        row: ri,
        x: 0,
        y: 0,
        left: 0,
        base: 0,
        ox: 0,
        oy: 0,
        or: 0,
        vx: 0,
        vy: 0,
        vr: 0,
        shown: false,
      });
    });
  });

  /* ---- fit the type to the box, kern the pairs, measure where everything rests ---- */
  const meas = document.createElement('canvas').getContext('2d');
  const tex = document.createElement('canvas');
  let W = 0,
    H = 0,
    F = 0,
    R0 = 100,
    texDirty = false;
  /** @type {{ x: number; y: number; h: number }[]} */
  let anchors = [];
  const fit = () => {
    W = el.clientWidth;
    H = el.clientHeight;
    if (!W || !H) return;
    const cs = getComputedStyle(head);
    const availW = head.clientWidth,
      padB = parseFloat(cs.bottom) || 0;
    const availH = H - nav.offsetHeight - padB - Math.max(6, W * 0.006);
    let widest = 1;
    if (meas) {
      meas.font = `700 100px ${FACE}`;
      const adv = (/** @type {string} */ s) => meas.measureText(s).width;
      rowEls.forEach((r) => {
        let rowW = 0;
        const words = Array.from(r.querySelectorAll('.krn-w'));
        words.forEach((w) => {
          const ls = Array.from(w.querySelectorAll('.krn-l')).map(
            (n) => /** @type {HTMLElement} */ (n),
          );
          ls.forEach((l, i) => {
            const a = l.textContent || '';
            let k = 0;
            if (i > 0) {
              const b = ls[i - 1].textContent || '';
              k = (adv(b + a) - adv(b) - adv(a)) / 100;
            }
            l.style.marginLeft = Math.abs(k) > 0.001 ? `${k.toFixed(4)}em` : '';
            rowW += adv(a) + (k + TRACK) * 100;
          });
        });
        rowW += (words.length - 1) * 42;
        widest = Math.max(widest, rowW);
      });
    }
    F = Math.max(
      24,
      Math.min((availW * 100) / widest, availH / (LEAD * rowEls.length)),
    );
    F = Math.round(F * 100) / 100;
    head.style.setProperty('--krn-f', `${F}px`);
    // rest positions (offset*, so the springs' transforms do not disturb them)
    const hx = head.offsetLeft,
      hy = head.offsetTop;
    const rowBox = rowEls.map((r) => {
      /** @type {HTMLElement | null} */
      const bl = r.querySelector('.krn-bl');
      return {
        top: hy + r.offsetTop,
        h: r.offsetHeight,
        base: hy + (bl?.offsetTop ?? r.offsetTop + r.offsetHeight * 0.95),
      };
    });
    letters.forEach((l) => {
      l.left = hx + l.el.offsetLeft;
      l.base = rowBox[l.row].base;
      l.x = l.left + l.el.offsetWidth / 2;
      l.y = rowBox[l.row].top + rowBox[l.row].h / 2;
    });
    const wordBox = rowEls.map((r) =>
      Array.from(r.querySelectorAll('.krn-w')).map((n) => {
        const w = /** @type {HTMLElement} */ (n);
        return { l: hx + w.offsetLeft, r: hx + w.offsetLeft + w.offsetWidth };
      }),
    );
    const L = hx,
      Rt = hx + head.clientWidth,
      cy = (/** @type {number} */ i) =>
        rowBox[Math.min(i, rowBox.length - 1)].top +
        rowBox[Math.min(i, rowBox.length - 1)].h / 2;
    const rh = rowBox[0].h;
    const gap = (/** @type {number} */ i) => {
      const w = wordBox[i] || [];
      return w.length > 1 ? (w[0].r + w[w.length - 1].l) / 2 : (L + Rt) / 2;
    };
    const w1 = wordBox[1]?.[0],
      w3 = wordBox[3]?.[0],
      w0b = wordBox[0]?.[wordBox[0].length - 1];
    R0 = Math.max(40, Math.min(F * 0.95, W * 0.2));
    // the loop: down into a gap (low), over the letters (high), into the next gap
    anchors = [
      { x: gap(0), y: cy(0) + rh * 0.08, h: 0.86 },
      {
        x: w0b ? w0b.l + (w0b.r - w0b.l) * 0.42 : Rt - W * 0.2,
        y: cy(0) + rh * 0.56,
        h: 2.05,
      },
      {
        x: w1
          ? Math.min(Rt - R0 * 0.8, w1.r + (Rt - w1.r) * 0.52)
          : Rt - W * 0.2,
        y: cy(1) + rh * 0.1,
        h: 0.9,
      },
      { x: L + (Rt - L) * 0.55, y: cy(1) + rh * 0.55, h: 2.3 },
      { x: gap(2), y: cy(2) + rh * 0.02, h: 0.86 },
      {
        x: w3
          ? Math.max(L + R0 * 0.95, (L + w3.l) / 2 + R0 * 0.25)
          : L + W * 0.14,
        y: cy(3) - rh * 0.5,
        h: 1.2,
      },
      { x: L + (Rt - L) * 0.3, y: cy(1) + rh * 0.38, h: 2.45 },
    ];
    anchors.forEach((a) => {
      a.x = Math.max(R0 * 0.92, Math.min(W - R0 * 0.92, a.x));
      a.y = Math.max(R0 * 1.02, Math.min(H - R0 * 0.9, a.y));
    });
    // the note lives in the gap left of the last row; when the type takes that, in the gap right of row 2
    if (noteEl) {
      noteEl.style.cssText = '';
      const tight = w3 ? w3.l - L < Math.max(190, W * 0.17) : true;
      if (W > 640 && tight) {
        const g = w1 ? Rt - w1.r : 0;
        if (w1 && g > Math.max(200, F * 0.9))
          noteEl.style.cssText = `left:${Math.round(w1.r + F * 0.16)}px;top:${Math.round(rowBox[1].top + F * 0.085)}px;bottom:auto;width:${Math.round(Math.min(g - F * 0.3, W * 0.17))}px`;
        else if (hy - nav.offsetHeight > 150)
          noteEl.style.cssText = `left:${Math.round(W * 0.016)}px;top:${Math.round(nav.offsetHeight + 34)}px;bottom:auto;width:${Math.round(Math.max(230, W * 0.3))}px`;
        else noteEl.style.cssText = 'visibility:hidden';
      }
    }
    // the page as the chrome sees it: the ground and the real letters
    const ts = Math.min(1, 1100 / W);
    tex.width = Math.max(2, Math.round(W * ts));
    tex.height = Math.max(2, Math.round(H * ts));
    const c = tex.getContext('2d');
    if (c) {
      c.fillStyle = ground;
      c.fillRect(0, 0, tex.width, tex.height);
      c.fillStyle = ink;
      c.font = `700 ${F * ts}px ${FACE}`;
      c.textBaseline = 'alphabetic';
      for (const l of letters) c.fillText(l.ch, l.left * ts, l.base * ts);
      texDirty = true;
    }
  };

  /* ---- the chrome form ---- */
  /** @type {WebGLRenderingContext | null} */
  let gl = null;
  /** @type {Record<string, WebGLUniformLocation | null>} */
  const U = {};
  let dpr = 1;
  const size = () => {
    dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    const w = Math.max(2, Math.round(W * dpr)),
      h = Math.max(2, Math.round(H * dpr));
    if (cv.width !== w || cv.height !== h) {
      cv.width = w;
      cv.height = h;
    }
  };
  const start = () => {
    const g = /** @type {WebGLRenderingContext | null} */ (
      cv.getContext('webgl', {
        premultipliedAlpha: true,
        alpha: true,
        antialias: false,
      })
    );
    if (!g) return;
    const sh = (/** @type {number} */ type, /** @type {string} */ src) => {
      const s = /** @type {WebGLShader} */ (g.createShader(type));
      g.shaderSource(s, src);
      g.compileShader(s);
      return s;
    };
    const pr = /** @type {WebGLProgram} */ (g.createProgram());
    g.attachShader(pr, sh(g.VERTEX_SHADER, VERT));
    g.attachShader(pr, sh(g.FRAGMENT_SHADER, FRAG));
    g.linkProgram(pr);
    if (!g.getProgramParameter(pr, g.LINK_STATUS)) return;
    g.useProgram(pr);
    g.bindBuffer(g.ARRAY_BUFFER, g.createBuffer());
    g.bufferData(
      g.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]),
      g.STATIC_DRAW,
    );
    const loc = g.getAttribLocation(pr, 'p');
    g.enableVertexAttribArray(loc);
    g.vertexAttribPointer(loc, 2, g.FLOAT, false, 0, 0);
    g.activeTexture(g.TEXTURE0);
    g.bindTexture(g.TEXTURE_2D, g.createTexture());
    g.texParameteri(g.TEXTURE_2D, g.TEXTURE_MIN_FILTER, g.LINEAR);
    g.texParameteri(g.TEXTURE_2D, g.TEXTURE_MAG_FILTER, g.LINEAR);
    g.texParameteri(g.TEXTURE_2D, g.TEXTURE_WRAP_S, g.CLAMP_TO_EDGE);
    g.texParameteri(g.TEXTURE_2D, g.TEXTURE_WRAP_T, g.CLAMP_TO_EDGE);
    ['uRes', 'uC', 'uR', 'uR0', 'uH', 'uM', 'uPage', 'uSh', 'uBurnt'].forEach(
      (n) => {
        U[n] = g.getUniformLocation(pr, n);
      },
    );
    g.uniform1i(U.uPage, 0);
    const bt = burntTint(ground);
    g.uniform3f(U.uBurnt, bt[0], bt[1], bt[2]);
    g.disable(g.BLEND);
    gl = g;
    texDirty = true;
    el.setAttribute('data-gl', '1');
  };

  /* ---- where it is, how it is turned ---- */
  const pos = { x: 0, y: 0, h: 1.4, set: false };
  const rot = [1, 0, 0, 0, 1, 0, 0, 0, 1]; // object → world, row by row
  let spin = 0.4;
  const ptr = { x: 0, y: 0, t: -1e9, kick: 0 };
  let T = 0;
  const dipUntil = 0;
  const LOOP = 10.4,
    FLIP = 4.6;
  const along = (/** @type {number} */ s) => {
    const n = anchors.length,
      f = (((s % 1) + 1) % 1) * n,
      i = Math.floor(f),
      t = f - i;
    const p0 = anchors[(i - 1 + n) % n],
      p1 = anchors[i % n],
      p2 = anchors[(i + 1) % n],
      p3 = anchors[(i + 2) % n];
    const cr = (
      /** @type {number} */ a,
      /** @type {number} */ b,
      /** @type {number} */ c,
      /** @type {number} */ d,
    ) =>
      0.5 *
      (2 * b +
        (c - a) * t +
        (2 * a - 5 * b + 4 * c - d) * t * t +
        (3 * b - a - 3 * c + d) * t * t * t);
    return {
      x: cr(p0.x, p1.x, p2.x, p3.x),
      y: cr(p0.y, p1.y, p2.y, p3.y),
      h: Math.max(0.8, cr(p0.h, p1.h, p2.h, p3.h)),
    };
  };
  const step = (/** @type {number} */ dt, /** @type {number} */ now) => {
    const s = dt / 1000,
      pc = live.pace;
    T += s * pc;
    // the turn: the form leans 9°–42° towards you (so its faces keep the studio in them), the lean walks round, it spins on its own axis,
    // and every few seconds it flips right over (the one moment it is seen edge on)
    ptr.kick *= Math.exp(-s * 1.6);
    spin += (1.9 + ptr.kick) * s * pc;
    const fl = T / FLIP,
      fi = Math.floor(fl),
      ff = Math.min(1, (fl - fi) / (0.95 / FLIP)),
      fe = ff * ff * ff * (ff * (ff * 6 - 15) + 10);
    const th = 0.45 + 0.29 * Math.sin(T * 1.7 + 0.4) + Math.PI * (fi + fe);
    const ph = 0.5 + T * 0.8 + 0.6 * Math.sin(T * 0.5);
    const ct = Math.cos(th),
      st = Math.sin(th),
      cf = Math.cos(ph),
      sf = Math.sin(ph),
      cs = Math.cos(spin),
      ss = Math.sin(spin);
    rot[0] = cf * cs - sf * ct * ss;
    rot[1] = -cf * ss - sf * ct * cs;
    rot[2] = sf * st;
    rot[3] = sf * cs + cf * ct * ss;
    rot[4] = -sf * ss + cf * ct * cs;
    rot[5] = -cf * st;
    rot[6] = st * ss;
    rot[7] = st * cs;
    rot[8] = ct;
    // the place: its own loop, or the hand
    const hand = now - ptr.t < 2200;
    const goal = hand
      ? { x: ptr.x, y: ptr.y, h: 1.05 }
      : along(T / LOOP + 0.02);
    if (!hand && now < dipUntil) goal.h = Math.min(goal.h, 0.9);
    if (!pos.set) {
      pos.x = goal.x;
      pos.y = goal.y;
      pos.h = goal.h;
      pos.set = true;
    }
    const rr = R0 * (1 + 0.1 * (goal.h - 1)) * 1.02; // never cut by the page's edge
    if (W > rr * 2.2 && H > rr * 2.2) {
      goal.x = Math.max(rr, Math.min(W - rr, goal.x));
      goal.y = Math.max(rr, Math.min(H - rr, goal.y));
    }
    const k = 1 - Math.exp(-s / (hand ? 0.16 : 0.09));
    pos.x += (goal.x - pos.x) * k;
    pos.y += (goal.y - pos.y) * k;
    pos.h += (goal.h - pos.h) * k;
  };

  /* ---- the letters make room ---- */
  const push = (/** @type {number} */ dt, /** @type {boolean} */ still) => {
    const s = Math.min(0.034, dt / 1000),
      amt = live.play;
    const close = Math.pow(Math.max(0, Math.min(1, (2.5 - pos.h) / 1.6)), 1.2);
    const reach = R0 * 2.05;
    for (const l of letters) {
      let tx = 0,
        ty = 0,
        tr = 0;
      if (!still && amt > 0) {
        const dx = l.x - pos.x,
          dy = l.y - pos.y,
          d = Math.hypot(dx, dy) + 0.001;
        const f = Math.pow(Math.max(0, 1 - d / reach), 1.5) * close * amt;
        if (f > 0) {
          const side = dx / d;
          tx = side * f * F * 0.07;
          ty = (dy / d) * f * F * 0.03;
          tr = -side * f * 17;
        }
      }
      l.vx += (170 * (tx - l.ox) - 15 * l.vx) * s;
      l.vy += (170 * (ty - l.oy) - 15 * l.vy) * s;
      l.vr += (170 * (tr - l.or) - 15 * l.vr) * s;
      l.ox += l.vx * s;
      l.oy += l.vy * s;
      l.or += l.vr * s;
      const on =
        Math.abs(l.ox) > 0.05 || Math.abs(l.oy) > 0.05 || Math.abs(l.or) > 0.02;
      if (on) {
        l.el.style.transform = `translate(${l.ox.toFixed(2)}px,${l.oy.toFixed(2)}px) skewX(${l.or.toFixed(2)}deg)`;
        l.shown = true;
      } else if (l.shown) {
        l.el.style.transform = '';
        l.shown = false;
      }
    }
  };

  const draw = () => {
    const g = gl;
    if (!g || !W) return;
    if (texDirty && tex.width > 1) {
      g.texImage2D(g.TEXTURE_2D, 0, g.RGBA, g.RGBA, g.UNSIGNED_BYTE, tex);
      texDirty = false;
    }
    const cw = cv.width,
      ch = cv.height;
    const r0 = R0 * dpr,
      r = r0 * (1 + 0.1 * (pos.h - 1)),
      cx = pos.x * dpr,
      cyy = pos.y * dpr;
    g.viewport(0, 0, cw, ch);
    g.disable(g.SCISSOR_TEST);
    g.clearColor(0, 0, 0, 0);
    g.clear(g.COLOR_BUFFER_BIT);
    // only the pixels the form and its shadow can reach
    const sx = cx + pos.h * 0.3 * r0,
      sy = cyy + pos.h * 0.4 * r0,
      sr = 1.78 * r0,
      or = 1.12 * r;
    const x0 = Math.max(0, Math.floor(Math.min(cx - or, sx - sr))),
      x1 = Math.min(cw, Math.ceil(Math.max(cx + or, sx + sr)));
    const y0 = Math.max(0, Math.floor(Math.min(cyy - or, sy - sr))),
      y1 = Math.min(ch, Math.ceil(Math.max(cyy + or, sy + sr)));
    if (x1 <= x0 || y1 <= y0) return;
    g.enable(g.SCISSOR_TEST);
    g.scissor(x0, ch - y1, x1 - x0, y1 - y0);
    // handed over row by row, which GL reads as the transpose: world → object
    g.uniformMatrix3fv(U.uM, false, rot);
    g.uniform2f(U.uRes, cw, ch);
    g.uniform2f(U.uC, cx, cyy);
    g.uniform1f(U.uR, r);
    g.uniform1f(U.uR0, r0);
    g.uniform1f(U.uH, pos.h);
    const lift = Math.max(0, Math.min(1, (pos.h - 0.8) / 1.7));
    g.uniform3f(
      U.uSh,
      11 - 6.5 * lift,
      0.7 - 0.3 * lift,
      0.3 * (1 - lift) * (1 - lift),
    );
    g.drawArrays(g.TRIANGLE_STRIP, 0, 4);
  };

  /* ---- the clock ---- */
  let raf = 0,
    last = 0,
    seen = true;
  const tick = (/** @type {number} */ now) => {
    raf = 0;
    const dt = last ? Math.min(50, now - last) : 16;
    last = now;
    if (live.autoplay || now - ptr.t < 2200 || now < dipUntil) step(dt, now);
    push(dt, false);
    draw();
    kick();
  };
  const still = () => {
    T = 3.3;
    pos.set = false;
    step(0, 0);
    push(0, true);
    letters.forEach((l) => {
      l.ox = l.oy = l.or = l.vx = l.vy = l.vr = 0;
      l.el.style.transform = '';
    });
    draw();
  };
  const kick = () => {
    if (dead) return;
    if (reduced.matches) {
      still();
      return;
    }
    if (!raf && seen && !document.hidden) raf = requestAnimationFrame(tick);
    if ((!seen || document.hidden) && raf) {
      cancelAnimationFrame(raf);
      raf = 0;
    }
    if (!seen || document.hidden) last = 0;
  };
  const relay = () => {
    fit();
    size();
    pos.set = pos.set && W > 0;
    if (reduced.matches) still();
  };

  fit();
  size();
  start();
  kick();
  // System faces need no download; this catches a late layout or a fallback face settling.
  document.fonts?.ready
    .then(() => {
      if (!dead) {
        relay();
        kick();
      }
    })
    .catch(() => {});

  let rz = 0;
  const ro =
    typeof ResizeObserver !== 'undefined'
      ? new ResizeObserver(() => {
          cancelAnimationFrame(rz);
          rz = requestAnimationFrame(() => {
            if (!dead) {
              relay();
              kick();
            }
          });
        })
      : null;
  ro?.observe(el);
  const io =
    typeof IntersectionObserver !== 'undefined'
      ? new IntersectionObserver(([e]) => {
          seen = e.isIntersecting;
          kick();
        })
      : null;
  io?.observe(el);
  const onVis = () => kick();
  document.addEventListener('visibilitychange', onVis);
  reduced.addEventListener?.('change', onVis);
  const onMove = (/** @type {PointerEvent} */ e) => {
    if (e.pointerType === 'touch') return;
    const b = el.getBoundingClientRect();
    const sc = b.width / (el.offsetWidth || 1) || 1;
    ptr.x = (e.clientX - b.left) / sc;
    ptr.y = (e.clientY - b.top) / sc;
    ptr.t = performance.now();
  };
  const onLeave = () => {
    ptr.t = -1e9;
  };
  const onDown = () => {
    ptr.kick = 7;
  };
  const onLost = (/** @type {Event} */ e) => {
    e.preventDefault();
    gl = null;
    el.removeAttribute('data-gl');
  };
  const onBack = () => {
    start();
    kick();
  };
  el.addEventListener('pointermove', onMove);
  el.addEventListener('pointerleave', onLeave);
  el.addEventListener('pointerdown', onDown);
  cv.addEventListener('webglcontextlost', onLost);
  cv.addEventListener('webglcontextrestored', onBack);

  return () => {
    dead = true;
    cancelAnimationFrame(raf);
    cancelAnimationFrame(rz);
    ro?.disconnect();
    io?.disconnect();
    document.removeEventListener('visibilitychange', onVis);
    reduced.removeEventListener?.('change', onVis);
    el.removeEventListener('pointermove', onMove);
    el.removeEventListener('pointerleave', onLeave);
    el.removeEventListener('pointerdown', onDown);
    cv.removeEventListener('webglcontextlost', onLost);
    cv.removeEventListener('webglcontextrestored', onBack);
    letters.forEach((l) => {
      l.el.style.transform = '';
    });
    if (noteEl) noteEl.style.cssText = '';
  };
}
