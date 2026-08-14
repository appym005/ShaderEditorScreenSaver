#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform vec2 resolution;
uniform float time;
uniform vec3 daytime;
uniform sampler2D backbuffer;

#define PI  3.14159265358979323846
#define TAU 6.28318530717958647692

float sat(float x) {
    return clamp(x, 0.0, 1.0);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; ++i) {
        v += noise2(p) * a;
        p = p * 2.03 + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return v;
}

float ring(float r, float radius, float width) {
    return exp(-abs(r - radius) / max(width, 0.0001));
}

float angleDistance(float a, float b) {
    return abs(atan(sin(a - b), cos(a - b)));
}

float clockAngle(vec2 p) {
    float a = atan(p.x, p.y);
    if (a < 0.0) {
        a += TAU;
    }
    return a;
}

vec3 GOLD() { return vec3(1.00, 0.46, 0.12); }
vec3 AMBER() { return vec3(1.00, 0.64, 0.27); }
vec3 PALE_GOLD() { return vec3(1.00, 0.82, 0.56); }
vec3 HOT_WHITE() { return vec3(1.00, 0.96, 0.88); }
vec3 VIOLET() { return vec3(0.47, 0.40, 1.00); }
vec3 DEEP_VIOLET() { return vec3(0.18, 0.14, 0.48); }
vec3 ICE() { return vec3(0.64, 0.74, 1.00); }

float starLayer(vec2 p, float scale, float threshold, float size) {
    vec2 grid = p * scale;
    vec2 cell = floor(grid);
    vec2 local = fract(grid) - 0.5;
    float rnd = hash21(cell);
    vec2 offset = vec2(hash21(cell + 7.31), hash21(cell + 11.93)) - 0.5;
    local -= offset * 0.55;
    float d = length(local);
    return smoothstep(size, 0.0, d) * smoothstep(threshold, 1.0, rnd);
}

vec3 starField(vec2 p, float r) {
    vec3 c = vec3(0.0);
    float s1 = starLayer(p, 65.0, 0.985, 0.085);
    float s2 = starLayer(p + 3.7, 118.0, 0.994, 0.095);
    float s3 = starLayer(p - 7.1, 36.0, 0.972, 0.055);
    float twinkle = 0.82 + 0.18 * sin(time * 0.17 + p.x * 18.0 + p.y * 11.0);
    float centralFade = 0.18 + 0.82 * smoothstep(0.42, 0.85, r);
    c += vec3(0.55, 0.62, 0.88) * s1 * twinkle * centralFade;
    c += vec3(0.95, 0.67, 0.40) * s2 * 0.65 * centralFade;
    c += vec3(0.72, 0.80, 1.00) * s3 * 0.42 * centralFade;
    return c;
}

void getClockState(out float smoothSecond, out vec4 newState) {
    vec2 stateUV = vec2(0.5 / resolution.x, 0.5 / resolution.y);
    vec4 prev = texture2D(backbuffer, stateUV);
    float wallSecond = daytime.z;
    bool initialized = prev.a > 0.5;
    float prevSecond = floor(prev.r * 59.0 + 0.5);
    float phase = prev.g;
    float currentPhase = fract(time);
    if (!initialized || abs(prevSecond - wallSecond) > 0.5) {
        phase = currentPhase;
    }
    float fraction = fract(currentPhase - phase + 1.0);
    smoothSecond = wallSecond + fraction;
    newState = vec4(wallSecond / 59.0, phase, 0.0, 1.0);
}

float lensCurve(vec2 p, float height, float curvature, float width) {
    float x = abs(p.x);
    float target = height / (1.0 + curvature * x * x);
    return exp(-abs(abs(p.y) - target) / width);
}

float geodesicBand(
    vec2 p,
    float signY,
    float heightL,
    float heightR,
    float curvL,
    float curvR,
    float widthL,
    float widthR,
    float offsetL,
    float offsetR,
    float skew,
    float flare
) {
    float side = smoothstep(-0.18, 0.22, p.x);
    float x = abs(p.x);
    float h = mix(heightL, heightR, side);
    float c = mix(curvL, curvR, side);
    float w = mix(widthL, widthR, side);
    float o = mix(offsetL, offsetR, side);
    float target = signY * (o + h / (1.0 + c * x * x));
    target += signY * skew * p.x * exp(-x * 1.85);
    target += signY * flare * x * smoothstep(0.16, 0.82, x);
    return exp(-abs(p.y - target) / w);
}

void main() {
    float smoothSecond;
    vec4 clockState;
    getClockState(smoothSecond, clockState);

    if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 1.0) {
        gl_FragColor = clockState;
        return;
    }

    float scale = min(resolution.x, resolution.y);
    vec2 p = (gl_FragCoord.xy - resolution.xy * 0.5) / scale * 2.0;
    float r = length(p);
    float theta = clockAngle(p);

    smoothSecond = mod(smoothSecond, 60.0);
    float minute = daytime.y + smoothSecond / 60.0;
    float hour = mod(daytime.x, 12.0) + minute / 60.0;
    float secondAngle = smoothSecond / 60.0 * TAU;
    float minuteAngle = minute / 60.0 * TAU;
    float hourAngle = hour / 12.0 * TAU;

    vec3 color = vec3(0.0007, 0.0008, 0.0015);

    float nebula = fbm(p * 2.4 + vec2(time * 0.003, 0.0));
    float nebula2 = fbm(p * 5.8 - vec2(2.1, 4.7));
    float nebulaMask = smoothstep(0.48, 0.82, nebula);
    nebulaMask *= 0.35 + 0.65 * smoothstep(0.48, 1.10, r);
    color += mix(vec3(0.025, 0.027, 0.055), vec3(0.075, 0.045, 0.105), nebula2) * nebulaMask * 0.20;
    color += starField(p, r) * 0.62;

    float bh = 0.142;
    float photonRadius = bh + 0.026;

    float safeR = max(r, 0.001);
    float gravity = 0.110 / (safeR + 0.045);
    float warpedR = r + gravity * 0.044;
    float angularBend = 0.38 * exp(-r * 3.2) * sin(theta * 2.0);
    float warpedTheta = theta + angularBend;

    float radialWave1 = abs(sin(warpedR * 28.0 * PI));
    float radialGrid1 = 1.0 - smoothstep(0.0, 0.047, radialWave1);
    float radialWave2 = abs(sin(warpedR * 56.0 * PI + 0.75));
    float radialGrid2 = 1.0 - smoothstep(0.0, 0.025, radialWave2);
    float angularWave1 = abs(sin(warpedTheta * 18.0));
    float angularGrid1 = 1.0 - smoothstep(0.0, 0.036, angularWave1);
    float angularWave2 = abs(sin(warpedTheta * 36.0 + warpedR * 2.0));
    float angularGrid2 = 1.0 - smoothstep(0.0, 0.020, angularWave2);

    float fabric = radialGrid1 * 0.45 + radialGrid2 * 0.18 + angularGrid1 * 0.42 + angularGrid2 * 0.14;
    float fabricMask = smoothstep(bh + 0.040, bh + 0.12, r) * (1.0 - smoothstep(0.86, 1.05, r));
    float centerBoost = 1.0 + 2.4 * exp(-r * 5.5);
    color += mix(
        vec3(0.13, 0.15, 0.30),
        vec3(0.27, 0.20, 0.41),
        0.42 + 0.35 * sin(warpedTheta * 2.0)
    ) * fabric * fabricMask * centerBoost * 0.20;

    float lensMask = smoothstep(bh - 0.005, bh + 0.025, r);
    float sideFade = 1.0 - smoothstep(0.74, 1.08, abs(p.x));

    float l1 = lensCurve(p, bh + 0.013, 18.0, 0.0037);
    float l2 = lensCurve(p, bh + 0.028, 16.6, 0.0042);
    float l3 = lensCurve(p, bh + 0.050, 14.0, 0.0054);
    float l4 = lensCurve(p, bh + 0.082, 11.5, 0.0070);
    float l5 = lensCurve(p, bh + 0.125, 8.8, 0.0100);

    l1 *= lensMask * sideFade;
    l2 *= lensMask * sideFade;
    l3 *= lensMask * sideFade;
    l4 *= lensMask * sideFade;
    l5 *= lensMask * sideFade;

    color += HOT_WHITE() * l1 * 0.36;
    color += PALE_GOLD() * l2 * 0.28;
    color += GOLD() * l3 * 0.18;
    color += VIOLET() * l4 * 0.11;
    color += DEEP_VIOLET() * l5 * 0.07;

    float innerMask = smoothstep(bh - 0.004, bh + 0.022, r) * (1.0 - smoothstep(0.66, 1.08, abs(p.x)));
    float hotSide = smoothstep(-0.08, 0.88, p.x);
    float coolSide = 1.0 - hotSide;

    float gt1 = geodesicBand(p, 1.0, bh + 0.010, bh + 0.004, 20.0, 28.0, 0.0032, 0.0026, 0.000, 0.000, 0.010, -0.002);
    float gt2 = geodesicBand(p, 1.0, bh + 0.022, bh + 0.015, 17.0, 24.0, 0.0042, 0.0034, 0.001, 0.002, -0.005, -0.003);
    float gt3 = geodesicBand(p, 1.0, bh + 0.040, bh + 0.030, 13.0, 18.0, 0.0057, 0.0046, 0.003, 0.005, 0.003, -0.004);
    float gb1 = geodesicBand(p, -1.0, bh + 0.006, bh + 0.011, 26.0, 18.0, 0.0029, 0.0035, 0.000, 0.000, 0.006, 0.002);
    float gb2 = geodesicBand(p, -1.0, bh + 0.017, bh + 0.024, 22.0, 15.5, 0.0037, 0.0045, 0.002, 0.002, -0.004, 0.003);
    float gb3 = geodesicBand(p, -1.0, bh + 0.031, bh + 0.045, 18.0, 12.0, 0.0050, 0.0062, 0.004, 0.004, 0.002, 0.005);

    gt1 *= innerMask;
    gt2 *= innerMask;
    gt3 *= innerMask;
    gb1 *= innerMask;
    gb2 *= innerMask;
    gb3 *= innerMask;

    color += HOT_WHITE() * gt1 * (0.48 + 0.50 * hotSide);
    color += mix(PALE_GOLD(), HOT_WHITE(), hotSide) * gt2 * (0.34 + 0.30 * hotSide);
    color += mix(AMBER(), PALE_GOLD(), 0.65) * gt3 * 0.20;
    color += mix(HOT_WHITE(), PALE_GOLD(), 0.65) * gb1 * (0.34 + 0.18 * coolSide);
    color += mix(AMBER(), GOLD(), hotSide) * gb2 * (0.22 + 0.24 * hotSide);
    color += mix(VIOLET(), GOLD(), 0.38 + 0.30 * hotSide) * gb3 * 0.16;

    float depthTop = geodesicBand(
        p - vec2(0.0, 0.025),
        1.0,
        bh + 0.036, bh + 0.026,
        12.0, 16.0,
        0.0068, 0.0052,
        0.004, 0.006,
        0.002, -0.003
    ) * innerMask;

    float depthBottom = geodesicBand(
        p + vec2(0.0, 0.022),
        -1.0,
        bh + 0.026, bh + 0.036,
        16.0, 12.0,
        0.0062, 0.0070,
        0.004, 0.004,
        -0.002, 0.004
    ) * innerMask;

    color += VIOLET() * depthTop * 0.08;
    color += AMBER() * depthBottom * 0.07;

    float wingTop = geodesicBand(
        p, 1.0,
        bh + 0.016, bh + 0.008,
        12.0, 16.0,
        0.013, 0.010,
        0.001, 0.001,
        0.003, -0.010
    );

    float wingBottom = geodesicBand(
        p, -1.0,
        bh + 0.009, bh + 0.014,
        15.0, 11.0,
        0.012, 0.013,
        0.001, 0.001,
        -0.002, 0.011
    );

    float wingMask = smoothstep(bh - 0.002, bh + 0.020, r) * (1.0 - smoothstep(0.74, 1.20, abs(p.x)));
    float wisp = 0.72 + 0.28 * fbm(vec2(abs(p.x) * 8.0 + 1.3, abs(p.y) * 24.0 + 3.7));
    wingTop *= wingMask * wisp;
    wingBottom *= wingMask * wisp;
    color += GOLD() * wingTop * 0.10 * (0.60 + 0.55 * hotSide);
    color += VIOLET() * wingBottom * 0.08 * (0.62 + 0.48 * coolSide);

    float photon1 = ring(r, photonRadius, 0.0023);
    float photon2 = ring(r, photonRadius + 0.008, 0.0035);
    float photon3 = ring(r, photonRadius + 0.018, 0.0052);
    float photon4 = ring(r, photonRadius + 0.034, 0.0080);

    float doppler = 0.5 + 0.5 * sin(theta + 0.90);
    float hotBias = pow(doppler, 1.35);
    float coolBias = pow(1.0 - doppler, 1.18);
    float irregular = 0.55 + 0.45 * fbm(vec2(theta * 2.6, 4.2));
    float angularPresence = 0.25 + 0.75 * sat(0.35 + 0.65 * sin(theta + 0.85));
    float ringPresence = irregular * angularPresence;

    color += HOT_WHITE() * photon1 * ringPresence * (0.18 + 0.88 * hotBias);
    color += PALE_GOLD() * photon2 * ringPresence * (0.14 + 0.46 * hotBias);
    color += mix(AMBER(), GOLD(), hotBias) * photon3 * (0.07 + 0.22 * hotBias);
    color += VIOLET() * photon3 * (0.05 + 0.10 * coolBias) * (0.40 + 0.60 * irregular);
    color += DEEP_VIOLET() * photon4 * 0.08 * (0.30 + 0.70 * coolBias);

    float rimFragment = pow(max(sin(theta * 8.0 + 0.9) * 0.5 + 0.5, 0.0), 7.0) * ring(r, photonRadius + 0.003, 0.0030);
    color += HOT_WHITE() * rimFragment * 0.20 * (0.4 + hotBias);

    float halo = exp(-max(r - bh, 0.0) * 8.0);
    color += mix(vec3(0.34, 0.22, 0.56), vec3(0.52, 0.24, 0.23), hotBias)
        * halo
        * (0.80 + 0.20 * sin(theta * 5.0 + time * 0.22))
        * 0.105;

    float hourOrbit = 0.710;
    float minuteOrbit = 0.555;
    float secondOrbit = 0.635;

    color += vec3(0.31, 0.28, 0.45) * ring(r, 0.395, 0.0012) * 0.10;
    color += vec3(0.31, 0.28, 0.45) * ring(r, 0.465, 0.0010) * 0.10;
    color += vec3(0.34, 0.31, 0.50) * ring(r, 0.785, 0.0012) * 0.12;
    color += vec3(0.38, 0.31, 0.43) * ring(r, 0.845, 0.0010) * 0.13;
    color += vec3(0.34, 0.30, 0.43) * ring(r, 0.905, 0.0009) * 0.10;

    float spokeWave = pow(max(cos(theta * 24.0), 0.0), 100.0);
    float spokeMask = smoothstep(0.31, 0.42, r) * (1.0 - smoothstep(0.82, 0.91, r));
    color += vec3(0.22, 0.21, 0.37) * spokeWave * spokeMask * 0.095;

    float dh = angleDistance(theta, hourAngle);
    float hourWide = exp(-pow(dh / 0.68, 2.0));
    float hourMedium = exp(-pow(dh / 0.38, 2.0));
    float hourCore = exp(-pow(dh / 0.17, 2.0));
    color += GOLD() * ring(r, hourOrbit, 0.025) * hourWide * 0.08;
    color += AMBER() * ring(r, hourOrbit, 0.010) * hourMedium * 0.33;
    color += PALE_GOLD() * ring(r, hourOrbit, 0.0048) * hourCore * 0.92;
    color += HOT_WHITE() * ring(r, hourOrbit, 0.0023) * hourCore * 0.66;

    float dm = angleDistance(theta, minuteAngle);
    float minuteWide = exp(-pow(dm / 0.60, 2.0));
    float minuteMedium = exp(-pow(dm / 0.34, 2.0));
    float minuteCore = exp(-pow(dm / 0.15, 2.0));
    color += DEEP_VIOLET() * ring(r, minuteOrbit, 0.024) * minuteWide * 0.12;
    color += VIOLET() * ring(r, minuteOrbit, 0.009) * minuteMedium * 0.40;
    color += ICE() * ring(r, minuteOrbit, 0.0038) * minuteCore * 0.76;

    vec2 hourPosition = vec2(sin(hourAngle), cos(hourAngle)) * hourOrbit;
    vec2 minutePosition = vec2(sin(minuteAngle), cos(minuteAngle)) * minuteOrbit;
    float hd = length(p - hourPosition);
    float md = length(p - minutePosition);
    color += GOLD() * exp(-hd * 45.0) * 0.36;
    color += PALE_GOLD() * exp(-hd * 92.0) * 1.02;
    color += HOT_WHITE() * exp(-hd * 180.0) * 0.95;
    color += VIOLET() * exp(-md * 48.0) * 0.34;
    color += ICE() * exp(-md * 102.0) * 1.00;
    color += vec3(1.0) * exp(-md * 185.0) * 0.75;

    float secondTrack = ring(r, secondOrbit, 0.0011);
    color += vec3(0.52, 0.59, 0.78) * secondTrack * 0.13;

    vec2 secondPosition = vec2(sin(secondAngle), cos(secondAngle)) * secondOrbit;
    float sd = length(p - secondPosition);
    float secondOuter = exp(-sd * 42.0);
    float secondInner = exp(-sd * 105.0);
    float secondCore = exp(-sd * 230.0);
    color += ICE() * secondOuter * 0.22;
    color += vec3(0.88, 0.92, 1.0) * secondInner * 0.66;
    color += vec3(1.0) * secondCore;

    float behind = mod(secondAngle - theta + TAU, TAU);
    float secondTail = exp(-behind * 6.7) * (1.0 - smoothstep(0.35, 0.90, behind));
    color += ICE() * secondTrack * secondTail * 0.33;

    float tickRadius = 0.875;
    float tickRing = ring(r, tickRadius, 0.0026);
    float secondTicks = pow(max(cos(theta * 60.0), 0.0), 70.0);
    color += vec3(0.55, 0.49, 0.56) * tickRing * secondTicks * 0.17;

    float hourTicks = pow(max(cos(theta * 12.0), 0.0), 95.0);
    color += PALE_GOLD() * ring(r, 0.870, 0.0055) * hourTicks * 0.48;

    float cardinal = pow(max(cos(theta * 4.0), 0.0), 120.0);
    color += HOT_WHITE() * ring(r, 0.875, 0.0085) * cardinal * 0.36;

    float pulseLife = 1.0 - smoothstep(0.0, 2.5, smoothSecond);
    float pulseRadius = 0.24 + smoothSecond * 0.205;
    float pulse1 = ring(r, pulseRadius, 0.009);
    float pulse2 = ring(r, pulseRadius + 0.032, 0.016);
    color += HOT_WHITE() * pulse1 * pulseLife * 0.26;
    color += mix(GOLD(), VIOLET(), smoothstep(0.0, 1.7, smoothSecond)) * pulse2 * pulseLife * 0.22;

    float core = 1.0 - smoothstep(bh - 0.004, bh + 0.003, r);
    color *= 1.0 - core;

    float shadowRing = ring(r, bh + 0.005, 0.010);
    color *= 1.0 - shadowRing * 0.22;

    float vignette = 1.0 - smoothstep(0.82, 1.34, r);
    color *= 0.18 + 0.82 * vignette;

    color = color / (1.0 + color * 0.62);
    color = pow(max(color, 0.0), vec3(0.82));

    gl_FragColor = vec4(color, 1.0);
}
