// — 1) Normalize payload — 
let data = msg.payload;

// if it comes in as a string, try to parse it
if (typeof data === "string") {
    try {
        data = JSON.parse(data);
    } catch (err) {
        node.error("Payload is not valid JSON", msg);
        return null;
    }
}

// — 2) Safely grab the 24h change —
let change =
    data.bitcoin &&
        typeof data.bitcoin.usd_24h_change === "number"
        ? data.bitcoin.usd_24h_change
        : null;

if (change === null) {
    node.warn("No bitcoin.usd_24h_change in payload", msg);
    return null;
}

// — 3) Determine HSB values based on thresholds —
let hue, sat = 1, bri = 1, brightns = 0, lightOn=false;

if (change > 4) {
    // up over 2%
    hue = 120;       // green
    brightns = 100;
    lightOn = true;
}
else if (change > 3) {
    // up over 2%
    hue = 120;       // green
    brightns = 75;
    lightOn = true;
}
else if (change > 2) {
    // up over 2%
    hue = 120;       // green
    brightns = 50;
    lightOn = true;
}
else if (change > 1) {
    // up 1–2%
    hue = 120;       // green
    sat = 0.5;       // light green
    brightns = 25;
    lightOn = true;
}
else if (change < -4) {
    hue = 0;       // red
    brightns = 100;
    lightOn = true;
}
else if (change < -3) {
    hue = 0;       // red
    brightns = 75;
    lightOn = true;
}
else if (change < -2) {
    // down over 2%
    hue = 0;       // red
    brightns = 50;
    lightOn = true;
}
else if (change < -1) {
    // down 1–2%
    hue = 60;       // yellow
    brightns = 25;
    lightOn = true;
}
else {
    // -1% to +1%
    hue = 240;       // blue
    lightOn = false;
}

// — 4) Convert to RGB and build final payload — 
//    (you must have HSBToRGB(h,s,b) in scope)
let rgb = HSBToRGB(hue, sat, bri);

msg.payload = {
    red: rgb.r,
    green: rgb.g,
    blue: rgb.b,
    brightness: brightns,
    on: lightOn
};

return msg;