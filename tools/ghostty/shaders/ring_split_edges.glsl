// Ring a split's edges by its state: red when a program flags it as needing
// attention, a soft glow when it's focused. Unfocused, unflagged splits pass
// through untouched.

// Pick a hue that pops against the black background.
const vec3 GLOW_COLOR = vec3(0xff, 0xe6, 0x1a) / 255.0;

// Set how far the glow reaches into the pane, in physical pixels (Retina 2x).
const float GLOW_REACH_PX = 20.0;

// Cap the glow's brightness at the very edge, so text near the frame stays legible.
const float GLOW_STRENGTH = 1.0;

// Flag a split by setting its background to this near-black with OSC 11
// (`\e]11;#010000\a`); OSC 111 clears it. Sit one step off the configured
// black, so the flag changes the ring without visibly changing the pane.
const vec3 ATTENTION_BACKGROUND = vec3(0x01, 0x00, 0x00) / 255.0;

// Match the decision red of the Hammerspoon Space dots, so both read alike.
const vec3 ATTENTION_COLOR = vec3(0xff, 0x3b, 0x30) / 255.0;

vec3 ring(vec3 base, vec3 color, float edgeDistance) {
    float strength = GLOW_STRENGTH * exp(-edgeDistance / (GLOW_REACH_PX / 3.0));
    return mix(base, color, strength);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    // Measure the distance to the nearest of the four pane edges.
    vec2 fromFarEdge = iResolution.xy - fragCoord;
    float edgeDistance = min(
        min(fragCoord.x, fromFarEdge.x),
        min(fragCoord.y, fromFarEdge.y)
    );

    // Match within half a color step, so float rounding can't miss the flag.
    bool needsAttention = distance(iBackgroundColor, ATTENTION_BACKGROUND) < 0.5 / 255.0;

    if (needsAttention) {
        fragColor = vec4(ring(terminal.rgb, ATTENTION_COLOR, edgeDistance), terminal.a);
    } else if (iFocus == 1) {
        fragColor = vec4(ring(terminal.rgb, GLOW_COLOR, edgeDistance), terminal.a);
    } else {
        fragColor = terminal;
    }
}
