// THE fresnel rim of the candy_lit family (render program T2). candy_lit includes
// it; shaders that keep their own lighting (skin, fur, bark, water, FX) include
// just this so every silhouette term in the game is the same curve.
#ifndef CANDY_RIM_INCLUDED
#define CANDY_RIM_INCLUDED
float candy_fresnel(vec3 n, vec3 v, float power) {
	return pow(max(1e-4, 1.0 - clamp(dot(n, v), 0.0, 1.0)), power);
}
#endif
