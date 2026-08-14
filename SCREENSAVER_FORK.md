# Shader Editor screen saver fork

Based on markusfisch/ShaderEditor 2.36.2 at commit
`c00a91a8170f1cb9dc0cb6dfab578ef9cd5b817d`.

Adds Android DreamService screen-saver support and a separate
"Set as screen saver" shader selection.

The sideload build removes Shader Editor's optional notification-listener
service because Google Play Protect automatically blocks internet-sideloaded
apps that declare that high-risk anti-fraud permission.

Includes Gravitational Clock v8 as a built-in sample: smooth wall-clock time
rendered as asymmetrical gravitational lensing, warped spacetime fabric,
luminous hour/minute geodesics, and an orbiting seconds body.
