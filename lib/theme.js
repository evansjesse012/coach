export const STYLES = `
  @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=DM+Sans:opsz,wght@9..40,300;9..40,400;9..40,500;9..40,600&family=JetBrains+Mono:wght@400;500&display=swap');
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  html,body{background:#F5F4F0;color:#1C1B2E;-webkit-font-smoothing:antialiased}
  input,textarea,button,select{font-family:inherit}
  ::-webkit-scrollbar{width:3px;height:3px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:#D0CFE0;border-radius:4px}
  @keyframes fadeUp{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
  @keyframes slideInRight{from{opacity:0;transform:translateX(100%)}to{opacity:1;transform:translateX(0)}}
  @keyframes blink{0%,80%,100%{opacity:.2;transform:scale(.7)}40%{opacity:1;transform:scale(1)}}
  @keyframes spin{to{transform:rotate(360deg)}}
  @keyframes toastIn{from{opacity:0;transform:translateY(-14px)}to{opacity:1;transform:translateY(0)}}
  .fade-up{animation:fadeUp .22s ease both}
  .slide-in{animation:slideInRight .28s cubic-bezier(.22,1,.36,1) both}
  .streaming-cursor::after{content:'▋';animation:blink 1s ease infinite;color:#E8604C;font-size:.9em;margin-left:1px}
  input[type=number]::-webkit-inner-spin-button{-webkit-appearance:none}
`;

export const LIGHT_C = {
  bg:'#F5F4F0', surface:'#FFFFFF', card:'#FFFFFF', elevated:'#F0EFF8',
  border:'#E8E7F0', borderBright:'#C8C7DC',
  text:'#1C1B2E', subtle:'#5C5B78', muted:'#A0A0BC',
  accent:'#E8604C', green:'#2ABF84', cyan:'#2BAFC4',
  yellow:'#F0A830', purple:'#8B6FE8', red:'#CC1111',
};
export const DARK_C = {
  bg:'#07070E', surface:'#0E0E1A', card:'#121222', elevated:'#1A1A2C',
  border:'#222236', borderBright:'#363658',
  text:'#EEEEF8', subtle:'#9898BE', muted:'#565678',
  accent:'#E8604C', green:'#2ABF84', cyan:'#2BAFC4',
  yellow:'#F0A830', purple:'#8B6FE8', red:'#CC1111',
};
export const LIGHT_S = {
  sm:'0 1px 3px rgba(28,27,46,.06),0 1px 2px rgba(28,27,46,.04)',
  md:'0 4px 12px rgba(28,27,46,.08),0 2px 4px rgba(28,27,46,.04)',
  lg:'0 8px 24px rgba(28,27,46,.10),0 2px 8px rgba(28,27,46,.06)',
  card:'0 2px 8px rgba(28,27,46,.07),0 0 0 1px rgba(28,27,46,.04)',
};
export const DARK_S = {
  sm:'none', md:'none',
  lg:'0 8px 32px rgba(0,0,0,.5)',
  card:'0 0 0 1px rgba(255,255,255,.05)',
};
export const C = { ...LIGHT_C };
export const S = { ...LIGHT_S };
export const F = { display:"'Outfit',sans-serif", ui:"'DM Sans',sans-serif", mono:"'JetBrains Mono',monospace" };
