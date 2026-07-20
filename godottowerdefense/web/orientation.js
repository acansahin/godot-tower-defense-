/*
 * Landscape gate for the Web build.
 *
 * Mobile browsers do not let a page force rotation on its own: Chrome only honours
 * screen.orientation.lock() while in fullscreen, and iOS Safari does not support it at
 * all. So this does the two things that actually work:
 *
 *   1. While the device is held in portrait, cover the page with a "rotate your device"
 *      panel, so nobody plays a 1280x720 game squeezed into a portrait strip.
 *   2. On tap, enter fullscreen and *then* ask for a landscape lock — on Android this
 *      genuinely rotates and pins the game. Where it is refused (iOS), the panel from
 *      step 1 still guides the player, so the fallback is graceful.
 *
 * Injected via the Web export preset's html/head_include; copied next to index.html by
 * .github/workflows/deploy.yml.
 */
(function () {
	"use strict";

	// Only gate touch devices — a narrow desktop window is not a phone, and nagging
	// someone who simply resized their browser would be obnoxious.
	if (!window.matchMedia || !window.matchMedia("(pointer: coarse)").matches) {
		return;
	}

	var style = document.createElement("style");
	style.textContent =
		"#rotate-gate{position:fixed;top:0;left:0;right:0;bottom:0;z-index:99999;" +
		"display:none;align-items:center;justify-content:center;flex-direction:column;" +
		"background:#12131a;color:#e8e8ef;text-align:center;padding:24px;" +
		"font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;}" +
		"#rotate-gate.show{display:flex;}" +
		"#rotate-gate .icon{font-size:64px;margin-bottom:18px;" +
		"animation:rg-tilt 1.8s ease-in-out infinite;}" +
		"#rotate-gate h1{font-size:22px;margin:0 0 10px;font-weight:600;}" +
		"#rotate-gate p{font-size:15px;margin:0;opacity:.75;line-height:1.5;}" +
		"@keyframes rg-tilt{0%,55%{transform:rotate(0)}80%,100%{transform:rotate(-90deg)}}";
	document.head.appendChild(style);

	var gate = document.createElement("div");
	gate.id = "rotate-gate";
	gate.innerHTML =
		'<div class="icon">&#128241;</div>' +
		"<h1>Please rotate your device</h1>" +
		"<p>Element TD is played in landscape.<br>Tap to go fullscreen.</p>";

	function isPortrait() {
		return window.matchMedia("(orientation: portrait)").matches;
	}

	function update() {
		gate.classList.toggle("show", isPortrait());
	}

	// Fullscreen first: it is the precondition Chrome puts on orientation locks.
	function goFullscreenLandscape() {
		var el = document.documentElement;
		var request = el.requestFullscreen || el.webkitRequestFullscreen;
		var pending = request ? request.call(el) : null;
		Promise.resolve(pending)
			.then(function () {
				if (window.screen && screen.orientation && screen.orientation.lock) {
					return screen.orientation.lock("landscape");
				}
			})
			.catch(function () {
				// Refused (iOS Safari, or fullscreen denied). The panel still tells the
				// player what to do, so there is nothing to recover from here.
			});
	}

	function mount() {
		document.body.appendChild(gate);
		gate.addEventListener("click", goFullscreenLandscape);
		update();
	}

	window.addEventListener("orientationchange", update);
	window.addEventListener("resize", update);
	var mq = window.matchMedia("(orientation: portrait)");
	if (mq.addEventListener) {
		mq.addEventListener("change", update);
	} else if (mq.addListener) {
		mq.addListener(update); // older WebKit
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", mount);
	} else {
		mount();
	}
})();
