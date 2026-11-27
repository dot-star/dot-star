// Ring the focused split with a soft inner glow, so the active pane reads at a
// glance even when every pane holds similar text. Unfocused splits pass through
// untouched.

// Pick a hue that pops against the black background.
const vec3 GLOW_COLOR = vec3(0xff, 0x8c, 0x00) / 255.0;

// Set how far the glow reaches into the pane, in physical pixels (Retina 2x).
const float GLOW_REACH_PX = 80.0;

// Cap the glow's brightness at the very edge, so text near the frame stays legible.
const float GLOW_STRENGTH = 0.9;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    if (iFocus == 0) {
        fragColor = terminal;
        return;
    }

    // Measure the distance to the nearest of the four pane edges.
    vec2 fromFarEdge = iResolution.xy - fragCoord;
    float edgeDistance = min(
        min(fragCoord.x, fromFarEdge.x),
        min(fragCoord.y, fromFarEdge.y)
    );

    float glow = GLOW_STRENGTH * exp(-edgeDistance / (GLOW_REACH_PX / 3.0));
    fragColor = vec4(mix(terminal.rgb, GLOW_COLOR, glow), terminal.a);
}
