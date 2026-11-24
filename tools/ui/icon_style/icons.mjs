// Shared icon geometry on a 48x48 grid. Each direction renders these its own way.
export const C = {
  rose:'#D9476F', blush:'#F3A9BC', red:'#C93B4C', wine:'#8C2C4B', coral:'#EE7F6B',
  leaf:'#5C9E6E', sage:'#9CC29B', mint:'#8FD6B8', forest:'#2F6B55',
  gold:'#D8A23F', butter:'#F3D57C', amber:'#E58A2E', orange:'#DD6E3A',
  lilac:'#B79CE0', violet:'#7B5AB8', peri:'#8EA2EA', sky:'#7FBFE8', teal:'#2E9E9E', navy:'#3C4A86',
  cream:'#F7EFDE', pearl:'#EFE8F3', bone:'#E8DFCB',
  brown:'#8B5B3D', tan:'#C99B6C', umber:'#4C3427',
  grey:'#9195A8', steel:'#B4B9C9', slate:'#565B73', ink:'#2B2838',
  venom:'#7FB548',
};
const f = n => +n.toFixed(2);
export const circ = (cx,cy,r)=>`M${f(cx-r)} ${cy}a${r} ${r} 0 1 0 ${f(2*r)} 0a${r} ${r} 0 1 0 ${f(-2*r)} 0Z`;
export const rr = (x,y,w,h,r)=>`M${f(x+r)} ${y}L${f(x+w-r)} ${y}Q${f(x+w)} ${y} ${f(x+w)} ${f(y+r)}L${f(x+w)} ${f(y+h-r)}Q${f(x+w)} ${f(y+h)} ${f(x+w-r)} ${f(y+h)}L${f(x+r)} ${f(y+h)}Q${x} ${f(y+h)} ${x} ${f(y+h-r)}L${x} ${f(y+r)}Q${x} ${y} ${f(x+r)} ${y}Z`;
export const star = (cx,cy,R,r,n=5,rot=-90)=>{let d='';for(let i=0;i<n*2;i++){const a=(rot+i*180/n)*Math.PI/180,rad=i%2?r:R;d+=(i?'L':'M')+f(cx+rad*Math.cos(a))+' '+f(cy+rad*Math.sin(a));}return d+'Z';};
export const spiral = (cx,cy,r0,r1,turns,a0=0,dir=1)=>{let d='';const N=Math.ceil(turns*28);for(let i=0;i<=N;i++){const t=i/N,a=(a0+dir*t*turns*360)*Math.PI/180,r=r0+(r1-r0)*t;d+=(i?'L':'M')+f(cx+r*Math.cos(a))+' '+f(cy+r*Math.sin(a));}return d;};
const gear = (cx,cy,R,r,n)=>{let d='';const step=360/n;for(let i=0;i<n;i++){const a=i*step;const pts=[[r,a-step*0.28],[R,a-step*0.17],[R,a+step*0.17],[r,a+step*0.28]];for(const [rad,ang] of pts){const q=ang*Math.PI/180;d+=(d?'L':'M')+f(cx+rad*Math.cos(q))+' '+f(cy+rad*Math.sin(q));}}return d+'Z';};
const scallop = (cx,cy,r,amp,n,rot=0)=>{let d='';const N=90;for(let i=0;i<N;i++){const a=i/N*2*Math.PI;const rad=r+amp*Math.cos(n*a+rot*Math.PI/180);d+=(i?'L':'M')+f(cx+rad*Math.cos(a))+' '+f(cy+rad*Math.sin(a));}return d+'Z';};
const pspiral = (cx,cy,r0,r1,turns,per,a0=0)=>{let d='';const N=Math.round(turns*per);for(let i=0;i<=N;i++){const t=i/N,a=(a0+i*360/per)*Math.PI/180,r=r0+(r1-r0)*Math.pow(t,0.85);d+=(i?'L':'M')+f(cx+r*Math.cos(a))+' '+f(cy+r*Math.sin(a));}return d;};
const R = deg => `rotate(${deg} 24 24)`;
const B=(d,fc,o={})=>({k:'B',d,f:fc,...o});
const L=(d,fc,o={})=>({k:'L',d,f:fc,...o});
const D=(d,o={})=>({k:'D',d,...o});
const H=(d,fc,o={})=>({k:'B',d,f:fc,hole:true,...o});
const V=(d,o={})=>({k:'B',d,void:true,...o});
const petal = 'M24 18.5C28.6 15 29 8.5 24 3.5C19 8.5 19.4 15 24 18.5Z';

export const ICONS = {
  // 1 Forageables
  rose:{name:'Red rose', main:C.red, parts:[
    L('M24 27C24 34 23.5 39 21.5 44.5', C.leaf),
    B('M23.4 37.5C26.5 32 32.5 31 37 33.2C34.5 38.2 28.5 40 23.4 37.5Z', C.leaf),
    B(scallop(24,16.5,12.3,0.9,5,-90), C.red),
    D(pspiral(24,16.5,1.6,9.4,2.3,5,160), {ess:true}),
  ]},
  cherry:{name:'Cherry', main:C.red, parts:[
    L('M15 25.5C16.5 17 22 11 29 8', C.leaf),
    L('M32.5 27.5C32.5 19 31 13 29 8', C.leaf),
    B('M29 8C32 3.2 38.5 3.6 42.5 8C38.5 12.8 32.5 12.6 29 8Z', C.leaf),
    B(circ(15,33.5,8), C.red),
    B(circ(32.8,35.5,8), C.red),
    D('M10.5 32a5 5 0 0 1 3.5-4'), D('M28.3 34a5 5 0 0 1 3.5-4'),
  ]},
  agaric:{name:'Fly agaric', main:C.red, parts:[
    B('M19 26C19.5 33 18 38 16.5 41.5C16 44.3 32 44.3 31.5 41.5C30 38 28.5 33 29 26Z', C.bone),
    B('M4.5 24.5C4.5 12.5 14 5 24 5C34 5 43.5 12.5 43.5 24.5C43.5 27.8 38 28.5 24 28.5C10 28.5 4.5 27.8 4.5 24.5Z', C.red),
    H(circ(15,16.5,2.9), C.cream), H(circ(26,11.5,2.4), C.cream), H(circ(34.5,19,2.7), C.cream), H(circ(23.5,21.5,2), C.cream),
  ]},
  // 2 Keepsakes
  feather:{name:'Kingfisher feather', main:C.teal, parts:[
    L('M24 30L24 46', C.amber, {t:R(35), w:.7}),
    B('M24 2.5C31.5 9 33.5 20 30.5 30C29.5 33.5 27 35.5 24 36.5C21 35.5 18.5 33.5 17.5 30C14.5 20 16.5 9 24 2.5Z', C.teal, {t:R(35)}),
    D('M24 9L24 37', {t:R(35), ess:true}),
    D('M24 18L30.6 12', {t:R(35)}), D('M24 27L32 20.8', {t:R(35)}),
    D('M24 22.5L16.4 16.5', {t:R(35)}), D('M24 31.5L16.6 26.5', {t:R(35)}),
  ]},
  shell:{name:'Spiral shell', main:C.tan, parts:[
    B('M25 5.5C36.5 5.5 43.5 14.5 43.5 24.5C43.5 34.5 35.5 42.5 25.5 42.5L6.5 42.5C9.5 38.5 8.5 34.5 7.5 30C5 17 13 5.5 25 5.5Z', C.tan),
    D('M25.5 42.5C33 41.5 37.3 34.5 36.3 27.3C35.3 20.3 29.5 15.6 23.5 16.6C18 17.6 15 22 16 26.6C17 30.6 21 32.6 24.5 31.6C27.5 30.6 28.8 27.6 27.6 25.4C26.6 23.6 24.3 23.5 23.3 25', {ess:true}),
  ]},
  gem:{name:'Garnet', main:C.wine, parts:[
    B('M15 7.5L33 7.5L42.5 19L24 42.5L5.5 19Z', C.wine),
    D('M5.5 19L42.5 19', {ess:true}), D('M17.5 19L24 7.5L30.5 19L24 42.5Z', {ess:true}),
  ]},
  // 3 Brews and dishes
  teacup:{name:'Hearth-warm tea', main:C.amber, parts:[
    L('M36.5 24.5C44 23.5 45 32.5 35 34', C.amber),
    B('M7.5 20.5L38 20.5C38 31.5 32.5 39.5 22.8 39.5C13 39.5 7.5 31.5 7.5 20.5Z', C.amber),
    L('M9 44L36.5 44', C.amber),
    L('M17.5 15.5C15.5 12.5 19.5 10 17.5 6', C.tan, {w:.7}),
    L('M27.5 15.5C25.5 12.5 29.5 10 27.5 6', C.tan, {w:.7}),
  ]},
  flask:{name:'Glow draught', main:C.teal, parts:[
    B('M20 9L28 9L28 18C35 21 39.5 26.5 39.5 31.5C39.5 38.5 33 43.5 24 43.5C15 43.5 8.5 38.5 8.5 31.5C8.5 26.5 13 21 20 18Z', C.mint),
    B('M11 31.5C15.5 29.5 19.5 33.5 24 32C28.5 30.5 32.5 33 37 31.5C37 37 31.5 41 24 41C16.5 41 11 37 11 31.5Z', C.teal, {only:['flat']}),
    D('M10.5 31.5C15.5 29.5 19.5 33.5 24 32C28.5 30.5 32.5 33 37.5 31.5', {not:['flat']}),
    B(rr(18,4,12,5.2,1.8), C.brown),
    H(circ(29.5,25.5,1.5), C.cream), H(circ(26,21.5,1), C.cream),
  ]},
  stew:{name:"Hunter's stew", main:C.slate, parts:[
    L('M12.5 18C12.5 4 35.5 4 35.5 18', C.slate, {w:.75}),
    B('M8 20L40 20C41.5 27 40 33 37.5 36.5C34.5 40.5 30 42.5 24 42.5C18 42.5 13.5 40.5 10.5 36.5C8 33 6.5 27 8 20Z', C.slate),
    B(rr(4.5,16.5,39,6,3), '#7A8099'),
    D('M13.5 28C14 32 15.8 35 18.5 37'),
  ]},
  // 4 Outfits
  gown:{name:'Ball gown', main:C.rose, parts:[
    B('M5.5 41.5C8 33 13 25 20.5 19.5L27.5 19.5C35 25 40 33 42.5 41.5C33 45 15 45 5.5 41.5Z', C.rose),
    B('M18 5.5C19 8.5 22 10.8 24 12.5C26 10.8 29 8.5 30 5.5L30.5 15C30.5 17 29 18.6 27.5 19.5L20.5 19.5C19 18.6 17.5 17 17.5 15Z', C.wine),
    D('M19.5 25C17 31 15.6 37 15.2 43.6'), D('M28.5 25C31 31 32.4 37 32.8 43.6'),
  ]},
  tiara:{name:'Tiara', main:C.gold, parts:[
    B('M9 34L12.5 19.5L18.5 28.5L24 10.5L29.5 28.5L35.5 19.5L39 34C33 32 15 32 9 34Z', C.gold),
    B('M5.5 33.5C13 30 35 30 42.5 33.5L42.5 38.5C35 35 13 35 5.5 38.5Z', C.gold),
    B(circ(24,8.5,2.9), C.rose), B(circ(12.5,17.5,2.3), C.rose), B(circ(35.5,17.5,2.3), C.rose),
    H('M24 18.5L26.2 23L24 27.5L21.8 23Z', C.cream),
  ]},
  mask:{name:'Butterfly mask', main:C.lilac, parts:[
    L('M4.4 19.5C1.6 25 3.6 30 1.8 35.5', C.violet, {w:.55}), L('M43.6 19.5C46.4 25 44.4 30 46.2 35.5', C.violet, {w:.55}),
    B('M4 17C10 12 19 14 24 19.5C29 14 38 12 44 17C45.5 25.5 40.5 33 33 33C28.5 33 26 28.5 24 26C22 28.5 19.5 33 15 33C7.5 33 2.5 25.5 4 17Z', C.lilac),
    V('M9.5 22C12.5 18.5 18 19.3 20.5 23.3C17.5 26.5 12.5 25.9 9.5 22Z'),
    V('M38.5 22C35.5 18.5 30 19.3 27.5 23.3C30.5 26.5 35.5 25.9 38.5 22Z'),
  ]},
  // 5 Bows, arrows, tools
  bow:{name:'Hunting bow', main:C.brown, parts:[
    L('M15 4.5L15 43.5', C.tan, {w:.45, t:R(30)}),
    L('M15 4.5C36 11 36 37 15 43.5', C.brown, {w:1.25, t:R(30)}),
    B(rr(28,19.2,5.5,9.6,2.6), C.umber, {t:R(30)}),
  ]},
  arrow:{name:'Fire arrow', main:C.amber, parts:[
    L('M7 41L30 18', C.brown),
    L('M7 41L7 34M7 41L14 41M11.8 36.2L11.8 29.2M11.8 36.2L18.8 36.2', C.tan, {w:.7}),
    B('M39.5 4.5C43.5 10 44.2 16.5 40.2 20.5C36.6 24 30.5 23.6 28 20C25.5 16.5 26.5 12 30 9.5C30 12.5 31.5 14 33.5 13.5C32.5 10.5 35.5 6.5 39.5 4.5Z', C.amber),
    H('M36.8 13C38.6 15.5 38.2 18.4 35.8 19.8C33.8 20.9 31.2 19.9 30.6 17.7C32.6 18.2 35.2 16.5 36.8 13Z', C.butter),
  ]},
  knife:{name:"Lucien's knife", main:C.steel, parts:[
    B('M24 2.5C27.5 9 28.5 18 28 27L20 27C19.5 18 20.5 9 24 2.5Z', C.steel, {t:R(40)}),
    D('M24 10.5L24 24', {t:R(40)}),
    B(rr(21.3,29,5.4,12,2.4), C.brown, {t:R(40)}),
    B(rr(15.5,26.2,17,3.8,1.9), C.gold, {t:R(40)}),
    B(circ(24,43.3,2.7), C.gold, {t:R(40)}),
  ]},
  // 6 Painting
  palette:{name:'Palette', main:C.tan, parts:[
    B('M24 5.5C36 5.5 44.5 13.5 44.5 23C44.5 30.5 39.5 32.5 34.5 31.5C30.5 30.7 28 32.5 29 36C30 39.5 27.5 42.5 22.5 42.5C12 42.5 3.5 34.5 3.5 24C3.5 13.5 12 5.5 24 5.5Z', C.tan),
    V(circ(35.5,22.5,3.2)),
    H(circ(13,20,3.2), C.rose), H(circ(20.5,12.8,3.2), C.butter), H(circ(29.5,12.5,3.2), C.sky), H(circ(11.5,29.5,3.2), C.lilac), H(circ(18.5,36.3,3), C.mint),
  ]},
  brush:{name:'Round sable', main:C.brown, parts:[
    B('M21.2 22L26.8 22C27.4 30 26 39 24 46C22 39 20.6 30 21.2 22Z', C.brown, {t:R(-40)}),
    B('M24 1.5C27 6 28.2 10.5 27.2 14.5L20.8 14.5C19.8 10.5 21 6 24 1.5Z', C.rose, {t:R(-40)}),
    B(rr(20.3,14,7.4,8.5,1.2), C.steel, {t:R(-40)}),
  ]},
  canvas:{name:'Canvas', main:C.brown, parts:[
    L('M15 31L10.5 44.5M33 31L37.5 44.5M24 31L24 41', C.brown, {w:.8}),
    L('M24 7L24 3.5', C.brown, {w:.8}),
    B(rr(7.5,7,33,24.5,2), C.cream),
    D('M11.5 26.5L19 17.5L24 23.5L29.5 15L36.5 26.5'),
    H(circ(16,13,2), C.gold),
  ]},
  // 7 Mare and tack
  mare:{name:'Her (the mare)', main:'#A99BC4', parts:[
    B('M28.5 2.5L31.5 9.5C38 13 42.5 22 43 33L43 44.5L17 44.5C19.5 40 20.5 36 19.5 31.5L13.5 34.5C11 36 7.5 35 6.5 32C5.8 29.6 7 27.5 9 25C13 19.5 17.5 13.5 24.5 9.5Z', '#DAD0E6'),
    B('M31.5 9.5C38 13 42.5 22 43 33L43 44.5L37.5 44.5C39 36 37 26.5 33.5 20C32 16.5 31 13 31.5 9.5Z', C.lilac),
    H(circ(22.5,18.5,1.5), C.ink), H(circ(9.6,30.6,1), C.ink),
  ]},
  manebow:{name:'Rose mane bow', main:C.rose, parts:[
    B('M21.5 25C19 31 16 36 11.5 41L18 40L20.5 44.5C22.5 38 23.8 32 24 26Z', C.wine),
    B('M26.5 25C29 31 32 36 36.5 41L30 40L27.5 44.5C25.5 38 24.2 32 24 26Z', C.wine),
    B('M22 20.5C15 11.5 7 11.5 5.5 16.5C4.5 22.5 6.5 28.5 10 30C15 30 19.5 26.5 22 23.5Z', C.rose),
    B('M26 20.5C33 11.5 41 11.5 42.5 16.5C43.5 22.5 41.5 28.5 38 30C33 30 28.5 26.5 26 23.5Z', C.rose),
    B(rr(20,18,8,8,3), C.wine),
  ]},
  horseshoe:{name:'Gold tack', main:C.gold, parts:[
    B('M10.5 43C2 27 6 5.5 24 5.5C42 5.5 46 27 37.5 43L30 43C35.5 29 34 14 24 14C14 14 12.5 29 18 43Z', C.gold),
    H(circ(10.4,29,1.4), C.umber), H(circ(12.5,18,1.4), C.umber), H(circ(24,9.8,1.4), C.umber), H(circ(35.5,18,1.4), C.umber), H(circ(37.6,29,1.4), C.umber),
  ]},
  // 8 Collection book, sketchbook, journal
  book:{name:'Collection book', main:C.wine, parts:[
    B(rr(2.5,13.5,43,30.5,2.5), C.wine),
    B('M22 40L26 40L26 47L24 45L22 47Z', C.rose),
    B('M4.5 10.5C11 7.5 18.5 8 24 12L24 41C18.5 37 11 36.5 4.5 39.5Z', C.cream),
    B('M43.5 10.5C37 7.5 29.5 8 24 12L24 41C29.5 37 37 36.5 43.5 39.5Z', C.cream),
    D('M9 17C12.5 15.8 16.5 16.1 19.5 17.7'), D('M9 23.5C12.5 22.3 16.5 22.6 19.5 24.2'), D('M9 30C12.5 28.8 16.5 29.1 19.5 30.7'),
    D('M39 17C35.5 15.8 31.5 16.1 28.5 17.7'), D('M39 23.5C35.5 22.3 31.5 22.6 28.5 24.2'),
  ]},
  ribbon:{name:'New ribbon', main:C.rose, parts:[
    B('M14.5 4L33.5 4L33.5 44.5L24 35.5L14.5 44.5Z', C.rose),
    H(star(24,17.5,7,3.1), C.butter),
  ]},
  pencil:{name:'Sketches', main:C.gold, parts:[
    B('M20.2 12L27.8 12L27.8 35.5L24 45.5L20.2 35.5Z', C.butter, {t:R(40)}),
    D('M20.2 35.5L27.8 35.5', {t:R(40)}),
    B('M22.4 41.2L25.6 41.2L24 45.5Z', C.slate, {t:R(40), only:['flat']}),
    B(rr(20.2,2.5,7.6,9.5,2.2), C.rose, {t:R(40)}),
  ]},
  // 9 Map
  flag:{name:'Waypoint pin', main:C.rose, parts:[
    L('M12.5 4.5L12.5 44.5', C.umber),
    L('M7 44.5L18 44.5', C.umber),
    B('M12.5 7L41 7L34.5 15L41 23L12.5 23Z', C.rose),
  ]},
  house:{name:'House', main:C.coral, parts:[
    B(rr(31.5,7.5,5.5,13,1), C.brown),
    B(rr(9,21,30,22.5,2), C.cream),
    B('M3 25.5L24 6L45 25.5Z', C.coral),
    H('M20.5 43.5L20.5 35C20.5 31 27.5 31 27.5 35L27.5 43.5Z', C.brown),
  ]},
  whorl:{name:'Whorl stone', main:C.grey, parts:[
    L('M5.5 43.5L42.5 43.5', C.sage, {w:.8}),
    B('M13.5 43.5C11.5 30 12.5 14 18.5 8C21.5 4.6 28 4.6 31 8C36 14 37 30 35 43.5Z', C.grey),
    D(spiral(24.4,24,1,7.6,2.1,90), {ess:true}),
  ]},
  // 10 HUD
  reticle:{name:'Aim reticle', main:C.slate, parts:[
    L('M24 2.5L24 9M24 39L24 45.5M2.5 24L9 24M39 24L45.5 24', C.slate, {w:.7}),
    L(circ(24,24,11.5), C.slate, {w:.7}),
    B(circ(24,24,1.9), C.rose),
  ]},
  stamina:{name:'Stamina rose wheel', main:C.rose, parts:[
    B(petal, C.rose, {t:R(0)}), B(petal, C.rose, {t:R(72)}), B(petal, C.rose, {t:R(144)}),
    B(petal, C.rose, {t:R(216), dim:true}), B(petal, C.rose, {t:R(288), dim:true}),
    B(circ(24,24,2.3), C.gold),
  ]},
  keyE:{name:'Interact key', main:C.slate, parts:[
    B(rr(6.5,6.5,35,35,8.5), C.slate),
    D('M30 15.5L19.5 15.5L19.5 32.5L30 32.5M19.5 24L28 24', {w:1.6, df:C.cream, ess:true}),
  ]},
  // 11 Status effects
  warm:{name:'Warm', main:C.amber, parts:[
    B('M25.5 3.5C27.5 11 36.5 16 36.5 27.5C36.5 36.5 31 43.5 24 43.5C17 43.5 11.5 37.5 11.5 29.5C11.5 23.5 14.5 19 18 15C18.5 19.5 20 21.8 22.6 22.8C21 16.5 21.5 9 25.5 3.5Z', C.amber),
    H('M24 43.5C20.5 43.5 18.3 40.8 18.3 37.5C18.3 33.5 22 31.5 23.5 27C27.2 30 29.7 33.8 29.7 37.5C29.7 41 27.5 43.5 24 43.5Z', C.butter),
  ]},
  swift:{name:'Swift', main:C.sky, parts:[
    B('M4.5 31C9 16.5 23.5 8 43.5 8C42 13 38 16.5 33.5 18C36 18.6 38.2 18.5 40.5 18C38 23.5 33 26.5 27.5 27C30 28 32.2 28 34.5 27.5C30.5 33.5 22.5 37 14 35C10.5 34.2 7.5 33 4.5 31Z', C.sky),
    D('M10.5 30C17 22.5 26 16.5 36.5 13'),
  ]},
  venom:{name:'Venom', main:C.venom, parts:[
    B('M24 4C30 14.5 37.5 23 37.5 31C37.5 38.5 31.5 43.5 24 43.5C16.5 43.5 10.5 38.5 10.5 31C10.5 23 18 14.5 24 4Z', C.venom),
    D('M27.8 23.8C24.8 21.2 19.8 22.6 19.8 26.2C19.8 30.6 28.4 29.6 28.4 34.4C28.4 37.8 23.2 39.4 20 36.6', {w:1.2, ess:true}),
  ]},
  // 12 Imbues and perks
  cloak:{name:'Hushed cloak', main:C.violet, parts:[
    B('M24 3.5C30.5 3.5 34.5 8.5 34.5 14C34.5 16 34 17.6 33.2 19C38.5 24.5 41.5 33 42.5 43.5L5.5 43.5C6.5 33 9.5 24.5 14.8 19C14 17.6 13.5 16 13.5 14C13.5 8.5 17.5 3.5 24 3.5Z', C.violet),
    H('M24 8C28 8 30.5 11 30.5 14.5C30.5 18.2 27.8 21 24 22.2C20.2 21 17.5 18.2 17.5 14.5C17.5 11 20 8 24 8Z', C.ink),
    D('M24 26.5L24 43.5'),
  ]},
  boot:{name:'Light-step boots', main:C.brown, parts:[
    B('M15 4.5L28.5 4.5L28.5 25.5C28.5 28.5 31.5 29.8 35.5 31.2C39.5 32.6 43 35 43 39.5L43 43.5L13.5 43.5L13.5 35.5C14.5 30.5 15 26 15 21.5Z', C.brown),
    D('M13.5 38.8L43 38.8'), D('M15 10.5L28.5 10.5'),
  ]},
  eye:{name:'Sight perk', main:C.peri, parts:[
    B('M2.5 24C10 12 38 12 45.5 24C38 36 10 36 2.5 24Z', C.peri),
    H(circ(24,24,8), C.cream),
    B(circ(24,24,3.6), C.navy),
  ]},
  // 13 Menus and chrome
  satchel:{name:'Satchel', main:C.brown, parts:[
    L('M13.5 16C13.5 2.5 34.5 2.5 34.5 16', C.umber, {w:.85}),
    B(rr(6,15,36,28.5,6), C.tan),
    B('M6 21C6 17.5 8.5 15 12 15L36 15C39.5 15 42 17.5 42 21L42 26C36 32.5 12 32.5 6 26Z', C.brown),
    B(rr(21,26.5,6,8.5,1.6), C.gold),
  ]},
  gear:{name:'Settings', main:C.slate, parts:[
    B(gear(24,24,20,15.2,8), C.slate),
    V(circ(24,24,6.2)),
  ]},
  coin:{name:'Coin', main:C.gold, parts:[
    B(circ(24,24,18.5), C.gold),
    D(circ(24,24,13.8)),
    H(star(24,24,6.8,3), C.butter),
  ]},
  // 14 Creatures
  stag:{name:'Deer', main:C.tan, parts:[
    L('M20.5 27C15.5 23.5 12 17 12 5', C.umber, {w:.8}), L('M13.3 16.5L6.5 12.5M12.3 11L17.5 6', C.umber, {w:.8}),
    L('M27.5 27C32.5 23.5 36 17 36 5', C.umber, {w:.8}), L('M34.7 16.5L41.5 12.5M35.7 11L30.5 6', C.umber, {w:.8}),
    B('M19.5 29C16 25.5 10.5 25.5 7 28.5C10 32 15.5 33 19.5 31.5Z', C.tan),
    B('M28.5 29C32 25.5 37.5 25.5 41 28.5C38 32 32.5 33 28.5 31.5Z', C.tan),
    B('M18.3 26.5L29.7 26.5C30.4 32 29 37.5 27.4 41.8C26.5 44.4 21.5 44.4 20.6 41.8C19 37.5 17.6 32 18.3 26.5Z', C.tan),
    H('M21.8 40.9C22.5 40.1 25.5 40.1 26.2 40.9C25.8 42.8 22.2 42.8 21.8 40.9Z', C.umber),
    H(circ(20.9,31.5,1.05), C.umber), H(circ(27.1,31.5,1.05), C.umber),
  ]},
  fox:{name:'Red fox', main:C.orange, parts:[
    B('M5 5.5L17.5 13C21.5 11.5 26.5 11.5 30.5 13L43 5.5C44 13.5 42.5 20.5 39.5 26C36 33 30.5 38 24 43.5C17.5 38 12 33 8.5 26C5.5 20.5 4 13.5 5 5.5Z', C.orange),
    B('M8.5 26C13.5 26.5 19 29.5 21.5 35L24 43.5C17.5 38 12 33 8.5 26Z', C.cream),
    B('M39.5 26C34.5 26.5 29 29.5 26.5 35L24 43.5C30.5 38 36 33 39.5 26Z', C.cream),
    H('M21.6 39.3L26.4 39.3L24 43.5Z', C.ink),
    H('M14.5 22.3L20 25.3L15 26Z', C.ink), H('M33.5 22.3L28 25.3L33 26Z', C.ink),
  ]},
  wolf:{name:'Wolf', main:C.slate, parts:[
    B('M8.5 3.5L18.5 15C21.5 13.6 26.5 13.6 29.5 15L39.5 3.5C42 11.5 41.5 19 39 24.5L33 35L28.5 44.5L19.5 44.5L15 35L9 24.5C6.5 19 6 11.5 8.5 3.5Z', C.slate),
    H('M13.5 22.5L21.5 26.8L15.5 27.8Z', C.butter), H('M34.5 22.5L26.5 26.8L32.5 27.8Z', C.butter),
    H('M21.2 40.5L26.8 40.5L24 43.6Z', C.ink),
  ]},
};

export const CATS = [
  ['Forageables and ingredients', ['rose','cherry','agaric']],
  ['Keepsakes and collectibles', ['feather','shell','gem']],
  ['Brews, dishes and recipes', ['teacup','flask','stew']],
  ['Outfits, jewellery, hair, makeup', ['gown','tiara','mask']],
  ['Bows, arrows and tools', ['bow','arrow','knife']],
  ['Painting and studio', ['palette','brush','canvas']],
  ['Mare and tack', ['mare','manebow','horseshoe']],
  ['Collection book and journal', ['book','ribbon','pencil']],
  ['Map and fast travel', ['flag','house','whorl']],
  ['HUD and in-play', ['reticle','stamina','keyE']],
  ['Status effects', ['warm','swift','venom']],
  ['Imbues and perk badges', ['cloak','boot','eye']],
  ['Menus and UI chrome', ['satchel','gear','coin']],
  ['Creatures and speakers', ['stag','fox','wolf']],
];

// Two-colour reduction for the flattest step: the item's own colour plus one accent.
export const TWO = {
  rose:{dom:C.red,acc:C.leaf}, cherry:{dom:C.red,acc:C.leaf}, agaric:{dom:C.red,acc:C.cream},
  feather:{dom:C.teal,acc:C.amber}, shell:{dom:C.tan}, gem:{dom:C.wine},
  teacup:{dom:C.amber,acc:C.tan}, flask:{dom:C.mint,acc:C.teal}, stew:{dom:C.slate,acc:'#7A8099'},
  gown:{dom:C.rose,acc:C.wine}, tiara:{dom:C.gold,acc:C.rose}, mask:{dom:C.lilac,acc:C.violet},
  bow:{dom:C.brown,acc:C.tan}, arrow:{dom:C.amber,acc:C.brown,map:{[C.butter]:'skip'}}, knife:{dom:C.steel,acc:C.brown},
  palette:{dom:C.tan,acc:C.rose}, brush:{dom:C.brown,acc:C.rose,map:{[C.steel]:'dom'}}, canvas:{dom:C.brown,acc:C.cream,map:{[C.gold]:'dom'}},
  mare:{dom:'#DAD0E6',acc:C.lilac}, manebow:{dom:C.rose,acc:C.wine}, horseshoe:{dom:C.gold,acc:C.umber},
  book:{dom:C.wine,acc:C.cream,map:{[C.rose]:'dom'}}, ribbon:{dom:C.rose,acc:C.butter}, pencil:{dom:C.butter,acc:C.rose},
  flag:{dom:C.rose,acc:C.umber}, house:{dom:C.coral,acc:C.cream,map:{[C.brown]:'dom'}}, whorl:{dom:C.grey,acc:C.sage},
  reticle:{dom:C.slate,acc:C.rose}, stamina:{dom:C.rose,acc:C.gold}, keyE:{dom:C.slate},
  warm:{dom:C.amber,acc:C.butter}, swift:{dom:C.sky}, venom:{dom:C.venom},
  cloak:{dom:C.violet,acc:C.ink}, boot:{dom:C.brown}, eye:{dom:C.peri,acc:C.cream,map:{[C.navy]:'dom'}},
  satchel:{dom:C.tan,acc:C.brown,map:{[C.gold]:'dom'}}, gear:{dom:C.slate}, coin:{dom:C.gold,acc:C.butter},
  stag:{dom:C.tan,acc:C.umber}, fox:{dom:C.orange,acc:C.cream}, wolf:{dom:C.slate,acc:C.butter,map:{[C.ink]:'skip'}},
};
