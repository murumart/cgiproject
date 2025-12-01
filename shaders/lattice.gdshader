shader_type spatial;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALPHA = 0.5;
	ALBEDO = COLOR.rgb;
	if (COLOR.r > 1.0 || COLOR.g > 1.0 || COLOR.b > 1.0) {
		ALBEDO = vec3(0);
		ALPHA = sin(TIME) * 0.5 + 0.5;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
