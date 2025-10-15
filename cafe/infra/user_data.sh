#!/bin/bash
set -eux
dnf install -y nginx || yum install -y nginx
systemctl enable nginx
mkdir -p /usr/share/nginx/html/assets
# Write CSS
cat > /usr/share/nginx/html/assets/styles.css <<'CSS'
:root{--bg:#0b0f19;--panel:#0f1629;--card:#111827;--text:#e5e7eb;--muted:#94a3b8;--accent:#d97706;--accent2:#f59e0b}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;line-height:1.6}
a{color:inherit;text-decoration:none}
a:focus-visible, .btn:focus-visible {outline:3px solid var(--accent2); outline-offset:2px}
.wrap{width:min(1100px,92%);margin-inline:auto}
.nav{display:flex;justify-content:space-between;align-items:center;padding:18px 0}
.brand{font-weight:800;letter-spacing:.8px}
.menu-links{display:flex;gap:18px;color:var(--muted)}
.hero{min-height:70vh;display:grid;place-items:center;background:linear-gradient(120deg,#1f2937,#0b0f19);position:relative;overflow:hidden}
.hero:before{content:"";position:absolute;inset:-20%;background:radial-gradient(600px 300px at 20% 20%,rgba(217,119,6,.2),transparent),radial-gradient(500px 260px at 80% 30%,rgba(59,130,246,.18),transparent)}
.hgrid{display:grid;grid-template-columns:1.1fr .9fr;gap:40px;align-items:center}
h1{font-size:48px;line-height:1.2;margin:0 0 10px}
.lead{color:var(--muted);font-size:18px;margin:0 0 20px}
.cta{display:flex;gap:12px}
.btn{padding:12px 18px;border-radius:10px;border:1px solid #334155;background:#0b1220;color:#e2e8f0;cursor:pointer;display:inline-block;min-height:44px}
.btn.accent{background:var(--accent);border-color:#b45309;color:#0b0f19;font-weight:700}
.cardgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin:40px 0}
.card{background:var(--card);padding:18px;border-radius:14px;border:1px solid #1f2937}
.card h3{margin:0 0 6px}
.panel{background:var(--panel);border-top:1px solid #1e293b;border-bottom:1px solid #1e293b;padding:50px 0}
.list{display:grid;grid-template-columns:repeat(2,1fr);gap:14px}
.item{display:flex;justify-content:space-between;background:#0c1424;border:1px solid #1e293b;padding:14px;border-radius:12px}
.gallery{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
.gallery img{width:100%;height:220px;object-fit:cover;border-radius:12px;border:1px solid #1f2937}
footer{padding:30px 0;color:var(--muted)}
.skip{position:absolute;left:-9999px;top:auto;width:1px;height:1px;overflow:hidden}
.skip:focus{position:static;width:auto;height:auto;display:inline-block;background:var(--accent);color:#0b0f19;padding:6px 10px;border-radius:8px;margin:8px}
@media(max-width:900px){.hgrid{grid-template-columns:1fr}.cardgrid{grid-template-columns:1fr}.list{grid-template-columns:1fr}.gallery{grid-template-columns:1fr} h1{font-size:34px}}
@media (prefers-reduced-motion: reduce){*{animation-duration:0.01ms !important;animation-iteration-count:1 !important;transition-duration:0.01ms !important;scroll-behavior:auto !important}}
CSS

# ---------- Index ----------
cat > /usr/share/nginx/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Barista Cafe</title>
<link rel="stylesheet" href="/assets/styles.css"/>
</head><body>
<a href="#main" class="skip">Skip to content</a>
<div class="wrap nav" role="navigation" aria-label="Primary">
  <div class="brand">BARISTA CAFE</div>
  <div class="menu-links">
    <a href="/index.html">Home</a>
    <a href="/menu.html">Menu</a>
    <a href="/about.html">About</a>
    <a href="/contact.html">Contact</a>
  </div>
</div>
<section class="hero" id="main">
  <div class="wrap hgrid">
    <div>
      <h1>Craft Coffee & Fresh Bakery</h1>
      <p class="lead">Small-batch roasts, artisan pastries, and a cozy space to meet or work.</p>
      <div class="cta">
        <a class="btn accent" href="/menu.html">View Menu</a>
        <a class="btn" href="/about.html">About Us</a>
      </div>
    </div>
    <div class="gallery" role="img" aria-label="Gallery of coffee, latte, and pastry images">
      <img loading="lazy" src="https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?q=80&w=1200&auto=format&fit=crop" alt="Coffee" />
      <img loading="lazy" src="https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?q=80&w=1200&auto=format&fit=crop" alt="Latte" />
      <img loading="lazy" src="https://images.unsplash.com/photo-1509440159598-8b9f91be3c23?q=80&w=1200&auto=format&fit=crop" alt="Pastry" />
    </div>
  </div>
</section>
<main id="main" role="main">
<div class="wrap panel">
  <div class="cardgrid">
    <div class="card"><h3>Single Origin</h3><p class="lead">Seasonal beans with bright notes.</p></div>
    <div class="card"><h3>Oat Latte</h3><p class="lead">Smooth, velvety, balanced.</p></div>
    <div class="card"><h3>Croissants</h3><p class="lead">Butter-forward, flaky layers.</p></div>
  </div>
</div>
<footer><div class="wrap">© <span id="y"></span> Barista Cafe • Follow @barista.cafe</div>
<script>document.getElementById('y').textContent=new Date().getFullYear()</script></footer>
</body></html>
HTML

# ---------- Menu ----------
cat > /usr/share/nginx/html/menu.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Menu • Barista Cafe</title>
<link rel="stylesheet" href="/assets/styles.css"/>
</head><body>
<a href="#main" class="skip">Skip to content</a>
<div class="wrap nav" role="navigation" aria-label="Primary">
  <div class="brand">BARISTA CAFE</div>
  <div class="menu-links">
    <a href="/index.html">Home</a>
    <a href="/menu.html">Menu</a>
    <a href="/about.html">About</a>
    <a href="/contact.html">Contact</a>
  </div>
</div>
<div class="wrap" id="main" style="padding:20px 0"><h1>Our Menu</h1><p class="lead">Signature drinks and fresh bakes.</p></div>
<section class="panel"><div class="wrap"><div class="list">
  <div class="item"><span>Espresso</span><span>$3.00</span></div>
  <div class="item"><span>Americano</span><span>$3.50</span></div>
  <div class="item"><span>Cappuccino</span><span>$4.50</span></div>
  <div class="item"><span>Oat Latte</span><span>$5.00</span></div>
  <div class="item"><span>Cold Brew</span><span>$4.00</span></div>
  <div class="item"><span>Matcha Latte</span><span>$5.50</span></div>
  <div class="item"><span>Butter Croissant</span><span>$3.25</span></div>
  <div class="item"><span>Almond Croissant</span><span>$3.95</span></div>
  <div class="item"><span>Chocolate Muffin</span><span>$3.75</span></div>
  <div class="item"><span>Banana Bread</span><span>$3.50</span></div>
</div></div></section>
<div class="wrap" style="padding:30px 0"><div class="gallery">
  <img loading="lazy" src="https://images.unsplash.com/photo-1517701604599-bb29b565090c?q=80&w=1200&auto=format&fit=crop" alt="Menu item"/>
  <img loading="lazy" src="https://images.unsplash.com/photo-1485808191679-5f86510681a2?q=80&w=1200&auto=format&fit=crop" alt="Menu item"/>
  <img loading="lazy" src="https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?q=80&w=1200&auto=format&fit=crop" alt="Menu item"/>
</div></div>
<footer><div class="wrap">© <span id="y"></span> Barista Cafe</div>
<script>document.getElementById('y').textContent=new Date().getFullYear()</script></footer>
</body></html>
HTML

# ---------- About ----------
cat > /usr/share/nginx/html/about.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>About • Barista Cafe</title>
<link rel="stylesheet" href="/assets/styles.css"/>
</head><body>
<a href="#main" class="skip">Skip to content</a>
<div class="wrap nav" role="navigation" aria-label="Primary">
  <div class="brand">BARISTA CAFE</div>
  <div class="menu-links">
    <a href="/index.html">Home</a>
    <a href="/menu.html">Menu</a>
    <a href="/about.html">About</a>
    <a href="/contact.html">Contact</a>
  </div>
</div>
<div class="wrap" id="main" style="padding:20px 0"><h1>Our Story</h1><p class="lead">From humble beans to unforgettable cups.</p></div>
<div class="wrap"><div class="cardgrid">
  <div class="card"><h3>Roasting</h3><p class="lead">We roast small batches weekly for peak freshness.</p></div>
  <div class="card"><h3>Ethics</h3><p class="lead">Direct-trade relationships with sustainable farms.</p></div>
  <div class="card"><h3>Community</h3><p class="lead">Workshops, cuppings, and open-mic nights.</p></div>
</div></div>
<div class="wrap" style="padding:30px 0"><div class="gallery">
  <img loading="lazy" src="https://images.unsplash.com/photo-1470337458703-46ad1756a187?q=80&w=1200&auto=format&fit=crop" alt="Roastery"/>
  <img loading="lazy" src="https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=1200&auto=format&fit=crop" alt="Bar"/>
  <img loading="lazy" src="https://images.unsplash.com/photo-1498804103079-a6351b050096?q=80&w=1200&auto=format&fit=crop" alt="Pastries"/>
</div></div>
<footer><div class="wrap">© <span id="y"></span> Barista Cafe</div>
<script>document.getElementById('y').textContent=new Date().getFullYear()</script></footer>
</body></html>
HTML

# ---------- Contact ----------
cat > /usr/share/nginx/html/contact.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Contact • Barista Cafe</title>
<link rel="stylesheet" href="/assets/styles.css"/>
</head><body>
<a href="#main" class="skip">Skip to content</a>
<div class="wrap nav" role="navigation" aria-label="Primary">
  <div class="brand">BARISTA CAFE</div>
  <div class="menu-links">
    <a href="/index.html">Home</a>
    <a href="/menu.html">Menu</a>
    <a href="/about.html">About</a>
    <a href="/contact.html">Contact</a>
  </div>
</div>
<div class="wrap" id="main" style="padding:20px 0"><h1>Contact Us</h1><p class="lead">We'd love to hear from you. Reach out for catering, events, or feedback.</p></div>
<div class="wrap"><div class="cardgrid">
  <div class="card"><h3>Address</h3><p>123 Roast Ave, Downtown</p></div>
  <div class="card"><h3>Email</h3><p><a href="#">hello@baristacafe.example</a></p></div>
  <div class="card"><h3>Phone</h3><p>(555) 123-4567</p></div>
</div></div>
<div class="wrap" style="padding:30px 0"><div class="gallery">
  <img loading="lazy" src="https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1200&auto=format&fit=crop" alt="Cafe interior"/>
  <img loading="lazy" src="https://images.unsplash.com/photo-1551218808-94e220e084d2?q=80&w=1200&auto=format&fit=crop" alt="Coffee"/>
  <img loading="lazy" src="https://images.unsplash.com/photo-1541167760496-1628856ab772?q=80&w=1200&auto=format&fit=crop" alt="Pastry"/>
</div></div>
<footer><div class="wrap">© <span id="y"></span> Barista Cafe</div>
<script>document.getElementById('y').textContent=new Date().getFullYear()</script></footer>
</body></html>
HTML

systemctl restart nginx
