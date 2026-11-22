/* Procedural hero visuals for directions D, E and F. Plain WebGL 1, one full-screen
   triangle, no textures, no images. Every picture here is computed per pixel from
   noise, the curve and the time of day. */
(function () {
  'use strict';

  const VERT = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';

  const NOISE = `
precision highp float;
float hash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float hash3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);vec2 u=f*f*(3.-2.*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
float noise3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
  return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
             mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec2 p){float a=.5,s=0.;mat2 m=mat2(1.6,1.2,-1.2,1.6);for(int i=0;i<5;i++){s+=a*noise(p);p=m*p;a*=.5;}return s;}
float fbm3(vec3 p){float a=.5,s=0.;for(int i=0;i<4;i++){s+=a*noise3(p);p=p*2.03+vec3(1.7,9.2,3.1);a*=.5;}return s;}
float bayer2(vec2 a){a=floor(a);return fract(a.x*.5+a.y*a.y*.75);}
float bayer4(vec2 a){return bayer2(.5*a)*.25+bayer2(a);}
float bayer8(vec2 a){return bayer4(.5*a)*.25+bayer2(a);}
/* one star per cell; cell and the returned glow are in canvas pixels, uPx = canvas px per css px */
float star(vec2 fc,float cell,float thr,float px,float t){
  vec2 g=floor(fc/cell);vec2 f=fract(fc/cell)-.5;float h=hash(g);
  if(h<thr)return 0.;
  vec2 o=vec2(hash(g+17.1),hash(g+31.7))-.5;
  float d=length(f-o*.6)*cell/px;
  float b=(h-thr)/(1.-thr);
  float tw=.78+.22*sin(t*(.5+1.7*b)+h*60.);
  return exp(-d*d*1.6)*b*tw;
}
`;

  /* D · Eclipse: a dark disc (the Ember mark) with a corona and a ring nebula around it.
     Daylight: wide cold corona, teal-to-rose ring. Evening: the corona pulls in and warms.
     Night: one ember crescent on the lower-right limb, as on the mark. */
  const ECLIPSE = `${NOISE}
uniform vec2 uRes;uniform float uTime;uniform vec2 uC;uniform float uR;uniform float uPx;
uniform vec3 uWhite;uniform float uWarm;uniform float uDim;
void main(){
  vec2 fc=gl_FragCoord.xy;
  vec2 p=(fc-uC)/uR;float r=length(p);vec2 dir=p/max(r,1e-4);
  float w=clamp(uWarm/.85,0.,1.);float wc=1.-pow(1.-w,2.2);float t=uTime;
  vec3 col=vec3(0.);
  float s=star(fc,26.*uPx,.84,uPx,t)+.55*star(fc+vec2(9.,4.)*uPx,11.*uPx,.9,uPx,t*1.3);
  vec3 sc=mix(vec3(.72,.84,1.),vec3(1.,.82,.66),hash(floor(fc/(26.*uPx))));
  col+=sc*s;
  vec2 dp=fc/uPx;
  col+=vec3(.035,.05,.10)*pow(fbm(dp/460.+vec2(3.,7.)),2.6)*2.2*(1.-.6*w);
  col+=vec3(.10,.035,.02)*pow(fbm(dp/340.+11.),2.6)*2.2*w;
  float x=max(r-1.,0.);
  float A=1.-smoothstep(.3,1.,w);
  float spread=mix(1.,.32,w);
  float fil=fbm(dir*2.6+vec2(r*.35-t*.012,t*.006));
  float fil2=fbm(dir*7.-vec2(r*.8,t*.01));
  float rays=pow(fil,2.2)*2.4+pow(fil2,3.)*1.6;
  float corona=exp(-x/(.09*spread+.012))*(.55+rays)+exp(-x/(.6*spread))*(.16+rays*.35);
  float ringR=mix(1.72,1.16,w);float ringW=mix(.40,.11,w);
  float rn=fbm(dir*5.+vec2(t*.01,0.)+r*.6);
  float rn2=fbm(dir*16.+r*2.-t*.02);
  float ring=exp(-pow((r-ringR)/ringW,2.))*(.2+1.25*pow(rn,1.5)+.35*rn2);
  float ringPos=clamp((r-(ringR-ringW))/(2.*ringW),0.,1.);
  vec2 L=vec2(.883,-.469);
  float lit=clamp(dot(dir,L)*.5+.5,0.,1.);
  float cres=pow(lit,4.)*exp(-x/(.022+.05*(1.-w)));
  float limb=exp(-abs(r-1.)*uR/(1.4*uPx));
  vec3 cold=vec3(.52,.72,1.),teal=vec3(.18,.82,.86),rose=vec3(1.,.36,.32);
  vec3 em=uWhite*vec3(1.,.8,.66);
  vec3 gold=vec3(1.,.66,.26),deep=vec3(1.,.30,.08);
  float w1=smoothstep(0.,.45,w),w2=smoothstep(.45,1.,w);
  vec3 coronaCol=mix(mix(mix(cold,vec3(1.),.3),mix(vec3(1.,.86,.62),em,.4),w1),em*vec3(1.,.85,.7),w2);
  vec3 ringCol=mix(mix(teal,rose,smoothstep(.15,.95,ringPos)),mix(gold,deep,ringPos),w1);
  ringCol=mix(ringCol,em*vec3(1.,.5,.3),w2);
  col+=coronaCol*corona*A*1.1;
  col+=ringCol*ring*(1.-.6*w);
  col+=em*cres*(1.1+1.8*w);
  col+=em*pow(lit,3.)*exp(-x/.14)*.55*w;
  col+=mix(vec3(.95,.97,1.),em,w)*limb*(.3+.7*lit*lit);
  float inside=1.-smoothstep(1.-.8*uPx/uR,1.,r);
  col*=1.-inside;
  col+=inside*em*.02*pow(lit,3.);
  col*=mix(.35,1.,uDim);
  col=1.-exp(-col*1.35);
  col+=(hash(fc+fract(t))-.5)/255.;
  gl_FragColor=vec4(col,1.);
}`;

  /* E · Dither sky: sky, sun, cumulus and a far and near ridge for the time of day, ordered-dithered
     to a small palette. The palette (zenith, middle, horizon, sun glow) comes from dir-def.js so the
     CSS fallback and the sections below paint the same colours. At night the horizon and a few
     the near ridge's edge glow in Ember's current colour (uWhite, uDim). The canvas runs at a
     fraction of the CSS size and scales up with nearest-neighbour, so every dither cell is a square. */
  const SKY = `${NOISE}
uniform vec2 uRes;uniform float uTime;uniform float uElev;uniform float uSunX;uniform float uLevels;uniform float uPx;
uniform float uHz;uniform float uPeak;uniform vec3 uZen;uniform vec3 uMid;uniform vec3 uHor;uniform vec3 uGlow;uniform vec3 uGround;
uniform vec3 uWhite;uniform float uDim;uniform float uNight;uniform float uGold;uniform float uDay;
float ridge(float x,float s,float a){return a*(.55*noise(vec2(x*s,s*7.))+.3*noise(vec2(x*s*2.3,s*3.))+.15*noise(vec2(x*s*5.,s)));}
void main(){
  vec2 fc=gl_FragCoord.xy;vec2 uv=fc/uRes;float asp=uRes.x/uRes.y;
  float e=uElev;float hz=uHz;
  float t=clamp((uv.y-hz)/(1.-hz),0.,1.);
  vec3 sky=mix(uHor,uMid,smoothstep(0.,.42,t));
  sky=mix(sky,uZen,smoothstep(.3,1.,t));
  vec2 pp=vec2(uv.x*asp,uv.y);
  float sy=hz+(1.-hz)*uPeak*e;
  vec2 sp=vec2(uSunX*asp,sy);
  vec2 dv=pp-sp;float sd=length(dv);
  float vis=smoothstep(-.06,.0,e);
  /* glow along the horizon on the sun's side, wide at sunrise and sunset */
  float hx=abs(pp.x-sp.x);
  float band=exp(-hx*(1.1+2.5*uDay))*exp(-max(uv.y-hz,0.)*(5.+6.*uDay));
  sky+=uGlow*band*(.75*uGold+.12*uDay)*smoothstep(-.32,-.02,e);
  sky+=uGlow*(exp(-sd*5.)*.42+exp(-sd*22.)*.6)*vis;
  /* crepuscular rays around a low sun */
  float ang=atan(dv.y,dv.x);
  float rays=pow(noise(vec2(ang*9.,uTime*.03)),3.)*exp(-sd*1.6)*smoothstep(0.,.25,dv.y+.05);
  sky+=uGlow*rays*.55*uGold*vis;
  /* stars and a faint band of dust */
  float above=smoothstep(hz+.02,hz+.3,uv.y);
  float st=star(fc,7.,.88,1.,uTime)*1.1+star(fc+3.,19.,.82,1.,uTime*.7)*1.6;
  vec2 mw=uv-vec2(.55,.62);float mwd=dot(mw,normalize(vec2(.55,1.)));
  float dust=exp(-mwd*mwd/.018)*pow(fbm(uv*vec2(6.,9.)+3.),2.)*.55;
  sky+=(vec3(.92,.94,1.)*st+vec3(.32,.30,.55)*dust)*uNight*above;
  /* cumulus, thinner at night */
  vec2 cp=pp*vec2(1.25,2.6)+vec2(uTime*.005,0.);
  float lift=uv.y-hz;
  float dens=fbm(cp*1.15)+.38*fbm(cp*3.2+4.)-lift*.78+.02-.12*uNight;
  float cover=smoothstep(.34,.52,dens)*smoothstep(-.02,.06,lift);
  vec2 toSun=normalize(vec2(sp.x-pp.x,sp.y-pp.y+.15));
  vec2 cq=cp+toSun*.07;
  float dens2=fbm(cq*1.15)+.38*fbm(cq*3.2+4.)-(lift+toSun.y*.07/2.6)*.78+.02-.12*uNight;
  float lit=clamp(.5+(dens-dens2)*4.,0.,1.);
  vec3 cTop=mix(uMid*.55+uZen*.2,vec3(1.),uDay);cTop=mix(cTop,uGlow*vec3(1.,.82,.72),uGold*.9);
  vec3 cBase=mix(uZen*.9+.015,uMid*.62+uZen*.2,uDay);cBase=mix(cBase,uMid*.7,uGold*.6);
  vec3 cloud=mix(cBase,cTop,lit);
  cloud+=uWhite*uDim*.10*uNight*(1.-t);
  sky=mix(sky,cloud,cover*(1.-.45*uNight));
  float disc=smoothstep(.034,.03,sd)*vis*(1.-cover*.85);
  sky=mix(sky,mix(vec3(1.,.72,.42),vec3(1.,.98,.92),smoothstep(0.,.2,e)),disc);
  /* Ember on the horizon at night */
  vec3 ember=uWhite*vec3(1.,.62,.42)*uDim;
  sky+=ember*exp(-max(uv.y-hz,0.)*6.)*(.5+.25*noise(vec2(uv.x*3.,2.)))*uNight;
  /* far ridge, hazy; near ridge, the ground the page stands on */
  float far=hz+.012+ridge(uv.x+.3,3.2,.07);
  float near=hz-.035+ridge(uv.x,5.5,.06)+.02*smoothstep(.55,1.,uv.x);
  vec3 farC=mix(uGround,uHor,.38+.12*uDay);
  farC+=uGlow*band*.35*uGold+ember*.12*uNight;
  float rim=exp(-abs(uv.y-far)*uRes.y*.5)*(uGold*.9*band+.25*uNight*exp(-abs(uv.x-.62)*2.));
  sky=mix(sky,farC,step(uv.y,far));
  sky+=uGlow*rim;
  float onNear=step(uv.y,near);
  vec3 g=uGround+uGlow*exp(-(near-uv.y)*40.)*band*.18*uGold+ember*exp(-(near-uv.y)*60.)*.10*uNight;
  sky=mix(sky,g,onNear);
  /* dither in a perceptual (square-root) space so dark skies keep their steps */
  float b=bayer8(fc);
  vec3 q=floor(sqrt(clamp(sky,0.,1.))*uLevels+b)/uLevels;
  gl_FragColor=vec4(q*q,1.);
}`;

  /* F · Limb: the edge of a planet seen from orbit, held over one place. Local solar time runs
     across the screen, so scrubbing moves the terminator. The night side lights in Ember's colour. */
  const LIMB = `${NOISE}
uniform vec2 uRes;uniform float uTime;uniform vec2 uC;uniform float uR;uniform float uPx;
uniform float uMin;uniform float uSpan;uniform vec3 uWhite;uniform float uDim;uniform float uLevels;uniform float uThick;
const float PI=3.14159265;const float RISE=421.;const float SET=1048.;
float elevAt(float m){m=mod(m,1440.);if(m>=RISE&&m<=SET)return sin(PI*(m-RISE)/(SET-RISE));return -sin(PI*mod(m-SET,1440.)/(1440.-(SET-RISE)));}
vec3 rainbow(float h){
  vec3 c=mix(vec3(.85,.10,.04),vec3(1.,.45,.08),smoothstep(0.,.22,h));
  c=mix(c,vec3(1.,.86,.42),smoothstep(.18,.42,h));
  c=mix(c,vec3(.30,.80,.78),smoothstep(.40,.65,h));
  return mix(c,vec3(.14,.26,.85),smoothstep(.6,1.,h));
}
void main(){
  vec2 fc=gl_FragCoord.xy;vec2 p=(fc-uC)/uR;float d=length(p);
  float xs=(fc.x/uRes.x-.5)*2.;
  float m=uMin+xs*uSpan;
  float e=elevAt(m);
  float dayL=smoothstep(-.03,.16,e);
  float tw=exp(-pow(e/.09,2.));
  float night=smoothstep(.0,-.1,e);
  vec3 col=vec3(0.);
  float ec=elevAt(uMin);
  float s=star(fc,22.*uPx,.86,uPx,uTime)+.5*star(fc+5.*uPx,9.*uPx,.92,uPx,uTime);
  col+=vec3(.85,.9,1.)*s*(1.-.65*smoothstep(0.,.5,ec));
  float hgt=(d-1.)*uR/uThick;
  if(d<1.){
    vec3 n=vec3(p,sqrt(1.-d*d));
    vec3 q=vec3(n.x,n.y*1.0,n.z);
    float land=smoothstep(.5,.55,fbm3(q*3.3+vec3(2.,0.,5.)));
    float cl=smoothstep(.52,.78,fbm3(q*7.+vec3(uTime*.004,0.,0.)));
    vec3 ocean=vec3(.03,.11,.30);
    vec3 ground=mix(vec3(.16,.24,.14),vec3(.44,.38,.27),fbm3(q*14.));
    vec3 surf=mix(ocean,ground,land);
    surf=mix(surf,vec3(.9,.93,.98),cl*.8);
    float shade=.3+.7*pow(n.z,.3);
    vec3 lit=surf*shade*dayL*1.15;
    lit+=vec3(1.,.42,.16)*tw*.22*shade;
    vec3 cq=q*260.;vec3 cell=floor(cq);
    float h=hash3(cell);
    vec3 off=vec3(hash3(cell+7.),hash3(cell+13.),hash3(cell+29.))-.5;
    float cd=length(fract(cq)-.5-off*.5);
    float pop=smoothstep(.42,.72,fbm3(q*8.+3.));
    float city=step(.9-pop*.12,h)*smoothstep(.32,.12,cd)*land*pop;
    float haze=pop*land*.2;
    vec3 cityC=uWhite*vec3(1.,.8,.58);
    lit+=cityC*(city*1.5+haze)*night*(1.-cl*.7)*mix(.6,1.,uDim);
    lit+=surf*vec3(.35,.45,.8)*.10*shade*(1.-dayL);
    col=lit;
    col+=vec3(.3,.55,1.)*exp(hgt*3.5)*.25*dayL;
  }
  float a=hgt>0.?exp(-hgt*2.4):exp(hgt*9.);
  vec3 dayA=mix(vec3(.78,.9,1.),vec3(.22,.46,1.),clamp(hgt,0.,1.));
  vec3 atmo=dayA*dayL*.9+rainbow(clamp(hgt,0.,1.))*tw*1.35;
  atmo+=uWhite*vec3(1.,.55,.3)*exp(-abs(hgt-.18)*7.)*.35*night;
  col+=atmo*a*(hgt>0.?1.:.55);
  float g=tw*exp(-pow(e/.035,2.))*exp(-abs(hgt-.05)*1.4);
  col+=vec3(1.,.86,.62)*g*1.6;
  col=1.-exp(-col*1.25);
  float b=bayer8(fc);
  vec3 qc=floor(clamp(col,0.,1.)*uLevels+b)/uLevels;
  gl_FragColor=vec4(qc,1.);
}`;

  /* ?gl=0 behaves as if the browser had no WebGL, to exercise the painted fallback. */
  const forceNoGL = new URLSearchParams(location.search).get('gl') === '0';

  /**
   * Bind a fragment shader to a canvas. o.pixel: CSS px per canvas px (dither looks), else
   * a device-pixel ratio capped at o.maxDpr. Returns null without WebGL. o.onLost and
   * o.onRestored follow the context: the program is rebuilt on restore.
   */
  function glView(canvas, frag, o = {}) {
    if (forceNoGL) return null;
    const gl = canvas.getContext('webgl', {
      antialias: false,
      alpha: false,
      depth: false,
      stencil: false,
      preserveDrawingBuffer: !!o.preserve,
      powerPreference: o.preserve ? 'default' : 'high-performance',
    });
    if (!gl) return null;
    const uni = new Map();
    let lost = false;
    const build = () => {
      uni.clear();
      const sh = (type, src) => {
        const s = gl.createShader(type);
        gl.shaderSource(s, src);
        gl.compileShader(s);
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS) && !gl.isContextLost())
          throw new Error(gl.getShaderInfoLog(s));
        return s;
      };
      const prog = gl.createProgram();
      gl.attachShader(prog, sh(gl.VERTEX_SHADER, VERT));
      gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, frag));
      gl.linkProgram(prog);
      if (!gl.getProgramParameter(prog, gl.LINK_STATUS) && !gl.isContextLost())
        throw new Error(gl.getProgramInfoLog(prog));
      gl.useProgram(prog);
      const buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(
        gl.ARRAY_BUFFER,
        new Float32Array([-1, -1, 3, -1, -1, 3]),
        gl.STATIC_DRAW,
      );
      const loc = gl.getAttribLocation(prog, 'p');
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      return prog;
    };
    let prog = build();
    const u = (name) => {
      if (!uni.has(name)) uni.set(name, gl.getUniformLocation(prog, name));
      return uni.get(name);
    };
    canvas.addEventListener('webglcontextlost', (e) => {
      e.preventDefault();
      lost = true;
      if (o.onLost) o.onLost();
    });
    canvas.addEventListener('webglcontextrestored', () => {
      try {
        prog = build();
      } catch (err) {
        console.warn('Ember shader rebuild failed', err);
        return;
      }
      lost = false;
      gl.viewport(0, 0, canvas.width, canvas.height);
      if (o.onRestored) o.onRestored();
    });
    const ratio = () =>
      o.pixel
        ? 1 / o.pixel
        : Math.min(window.devicePixelRatio || 1, o.maxDpr || 1.5);
    let cssW = 0;
    let cssH = 0;
    const api = {
      gl,
      canvas,
      /** canvas px per CSS px */
      px: ratio(),
      get lost() {
        return lost;
      },
      resize(w, h) {
        cssW = w;
        cssH = h;
        api.px = ratio();
        const W = Math.max(1, Math.round(w * api.px));
        const H = Math.max(1, Math.round(h * api.px));
        if (canvas.width !== W || canvas.height !== H) {
          canvas.width = W;
          canvas.height = H;
        }
        gl.viewport(0, 0, W, H);
      },
      get size() {
        return { w: cssW, h: cssH, W: canvas.width, H: canvas.height };
      },
      render(values) {
        if (lost) return false;
        gl.uniform2f(u('uRes'), canvas.width, canvas.height);
        gl.uniform1f(u('uPx'), api.px);
        for (const k in values) {
          const v = values[k];
          const l = u(k);
          if (l == null) continue;
          if (typeof v === 'number') gl.uniform1f(l, v);
          else if (v.length === 2) gl.uniform2f(l, v[0], v[1]);
          else gl.uniform3f(l, v[0], v[1], v[2]);
        }
        gl.drawArrays(gl.TRIANGLES, 0, 3);
        return true;
      },
      dispose() {
        const ext = gl.getExtension('WEBGL_lose_context');
        if (ext) ext.loseContext();
      },
    };
    return api;
  }

  window.EmberGL = { glView, ECLIPSE, SKY, LIMB };
})();
