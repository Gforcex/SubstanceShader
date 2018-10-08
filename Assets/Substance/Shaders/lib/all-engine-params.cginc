
//Basic usage :
//: param auto TEXTURE_TAG
uniform sampler2D uniform_tex;   // The texture itself

								 //: param auto TEXTURE_TAG_is_set
uniform bool uniform_tex_is_set; // A boolean indicating whether the texture is in document or not

								 //: param auto TEXTURE_TAG_size
uniform vec4 uniform_tex_size;   // The size of the texture (width, height, 1/width, 1/height)



//Texture parameters allow to use 'or' operator to define a fallback :
//: param auto TEXTURE_TAG_1 or TEXTURE_TAG_2
uniform sampler2D uniform_tex; // if TEXTURE_TAG_1 exists then TEXTURE_TAG_1 else TEXTURE_TAG_2

							   //: param auto TEX_TAG_1_size or TEX_TAG_2_size
uniform vec4 uniform_tex_size; // if TEX_TAG_1 exists then TEX_TAG_1_size else TEX_TAG_2_size


//Other parameters

//aspect_ratio: a float containing the viewport width / height ratio
//: param auto aspect_ratio
uniform float uniform_aspect_ratio;

//camera_view_matrix: a mat4 representing the transformation from world space to camera space
//: param auto camera_view_matrix
uniform mat4 uniform_camera_view_matrix;

//camera_view_matrix_it: inverse transpose version of camera_view_matrix
//: param auto camera_view_matrix_it
uniform mat4 uniform_camera_view_matrix_it;

//camera_vp_matrix_inverse: inverse of projection * camera_view_matrix matrix 
//: param auto camera_vp_matrix_inverse
uniform mat4 uniform_camera_vp_matrix_inverse;

//environment_exposure: a float representing the envmap's exposure
//: param auto environment_exposure
uniform float uniform_environment_exposure;

//environment_max_lod: a float representing the envmap's depth of mip-map pyramid
//: param auto environment_max_lod
uniform float uniform_max_lod;

//environment_rotation: a float representing the envmap's rotation around up axis
//the value is in the range [0,1] and should be maped to the range [0, 2*pi]
//: param auto environment_rotation
uniform float uniform_environment_rotation;

//facing: an integer indicating rendered faces (-1: back faces, 0: undefined, 1: front faces)
//value of 0 means you can safely rely on glsl built-in variable gl_FrontFacing
//: param auto facing
uniform int uniform_facing;

//fovy: a float representing the camera field of view along Y axis
//: param auto fovy
uniform float uniform_fovy;

//is_2d_view: a bool indicating whether the rendering is performed for 2D view or not
//: param auto is_2d_view
uniform bool uniform_2d_view;

//is_perspective_projection: a bool indicating whether the projection is perspective or orthographic
//: param auto is_perspective_projection
uniform bool uniform_perspective_projection;

//main_light: a vec4 indicating the position of the main light in the environment
//: param auto main_light
uniform vec4 uniform_main_light;

//mvp_matrix: a mat4 representing the model view projection matrix
//: param auto mvp_matrix
uniform mat4 uniform_mvp_matrix;

//scene_original_radius: a float representing the radius of the scene's bounding sphere before its normalization
//: param auto scene_original_radius
uniform float uniform_scene_original_radius;

//screen_size: a vec4 containing screen size data (width, height, 1/width, 1/height)
//: param auto screen_size
uniform vec4 uniform_screen_size;

//world_camera_direction: a vec3 representing the world camera orientation
//: param auto world_camera_direction
uniform vec3 uniform_world_camera_direction;

//world_eye_position: a vec3 representing the world eye position
//: param auto world_eye_position
uniform vec3 uniform_world_eye_position;
