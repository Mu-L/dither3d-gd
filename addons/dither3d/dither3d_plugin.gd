@tool
extends EditorPlugin

const DitherGeneratorScript = preload("scripts/Dither3DTextureGenerator.gd")
const SceneConverterDialog = preload("scripts/Dither3DSceneConverterDialog.gd")

var _main_popup_menu: PopupMenu
var _textures_popup_menu: PopupMenu
var _scenes_popup_menu: PopupMenu
var _scene_converter_dialog: ConfirmationDialog

func _enter_tree():
	add_custom_type("Dither3DGlobalProperties", "Node", preload("scripts/Dither3DGlobalProperties.gd"), preload("icon.svg"))
	
	_scene_converter_dialog = SceneConverterDialog.new()
	add_child(_scene_converter_dialog)
	_scene_converter_dialog.generate_requested.connect(_on_scene_convert_requested)
	
	_setup_tool_menu()

func _exit_tree():
	remove_custom_type("Dither3DGlobalProperties")
	
	if _scene_converter_dialog:
		_scene_converter_dialog.queue_free()
	
	_remove_tool_menu()

func _setup_tool_menu():
	# Create the Textures submenu
	_textures_popup_menu = PopupMenu.new()
	_textures_popup_menu.name = "Textures"
	_textures_popup_menu.add_item("Generate 1x1 (Bayer)", 0)
	_textures_popup_menu.add_item("Generate 2x2 (Bayer)", 1)
	_textures_popup_menu.add_item("Generate 4x4 (Bayer)", 2)
	_textures_popup_menu.add_item("Generate 8x8 (Bayer)", 3)
	_textures_popup_menu.add_separator()
	_textures_popup_menu.add_item("Generate All Standard", 100)
	
	_textures_popup_menu.id_pressed.connect(_on_textures_menu_item_pressed)
	
	# Create the Scenes submenu
	_scenes_popup_menu = PopupMenu.new()
	_scenes_popup_menu.name = "Scenes"
	_scenes_popup_menu.add_item("Create Dither3D Copy from Scene...", 0)
	
	_scenes_popup_menu.id_pressed.connect(_on_scenes_menu_item_pressed)
	
	# Create the main Dither3D menu
	_main_popup_menu = PopupMenu.new()
	_main_popup_menu.name = "Dither3D"
	
	# Add Textures submenu to main menu
	_main_popup_menu.add_child(_textures_popup_menu)
	_main_popup_menu.add_submenu_item("Textures", "Textures")
	
	# Add Scenes submenu to main menu
	_main_popup_menu.add_child(_scenes_popup_menu)
	_main_popup_menu.add_submenu_item("Scenes", "Scenes")
	
	# Add the main menu to Project > Tools
	add_tool_submenu_item("Dither3D", _main_popup_menu)

func _remove_tool_menu():
	remove_tool_menu_item("Dither3D")
	
	if _main_popup_menu:
		_main_popup_menu.queue_free()
		_main_popup_menu = null
		# _textures_popup_menu is a child of _main_popup_menu, so it will be freed automatically

func _on_textures_menu_item_pressed(id: int):
	match id:
		0: _run_generator(0)
		1: _run_generator(1)
		2: _run_generator(2)
		3: _run_generator(3)
		100: _generate_all()

func _generate_all():
	var generator = DitherGeneratorScript.new()
	generator.generate_all_textures()
	generator.free()
	# Rescan to show new files in FileSystem dock
	get_editor_interface().get_resource_filesystem().scan()

func _run_generator(recursion: int):
	var generator = DitherGeneratorScript.new()
	generator.create_dither_3d_texture(recursion)
	generator.free()
	# Rescan to show new files in FileSystem dock
	get_editor_interface().get_resource_filesystem().scan()

func _on_scenes_menu_item_pressed(id: int):
	match id:
		0: _scene_converter_dialog.popup_centered()

func _on_scene_convert_requested(path: String):
	print("Dither3D: Generate requested for scene: ", path)
	
	if path.is_empty():
		printerr("Dither3D: No scene path provided.")
		return
	
	var dir = path.get_base_dir()
	var file_name = path.get_file().get_basename()
	var extension = path.get_extension()
	var new_path = dir + "/" + file_name + "_Dither3D." + extension
	
	# Load the original scene
	var packed_scene = load(path)
	if not packed_scene:
		printerr("Dither3D: Failed to load scene: ", path)
		return
		
	var root = packed_scene.instantiate()
	if not root:
		printerr("Dither3D: Failed to instantiate scene.")
		return
	
	# Modify the scene
	_recursive_apply_dither(root)
	
	# Pack and Save
	var new_packed_scene = PackedScene.new()
	var pack_result = new_packed_scene.pack(root)
	if pack_result != OK:
		printerr("Dither3D: Failed to pack modified scene.")
		root.free()
		return
		
	var save_result = ResourceSaver.save(new_packed_scene, new_path)
	if save_result != OK:
		printerr("Dither3D: Failed to save new scene.")
	else:
		print("Dither3D: Successfully created Dither3D scene: ", new_path)
		get_editor_interface().get_resource_filesystem().scan()
	
	root.free()

func _recursive_apply_dither(node: Node):
	# Process GeometryInstance3D (MeshInstance3D, CSGShape3D, etc.)
	if node is GeometryInstance3D:
		if node.material_override:
			node.material_override = _append_dither_pass(node.material_override)
		if node.material_overlay:
			node.material_overlay = _append_dither_pass(node.material_overlay)
			
	# Specific handling for MeshInstance3D surfaces
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = node.get_surface_override_material(i)
				if not mat:
					mat = mesh.surface_get_material(i)
				
				if mat:
					var new_mat = _append_dither_pass(mat)
					node.set_surface_override_material(i, new_mat)
					
	# Specific handling for CSGShape3D material slot
	elif node is CSGShape3D:
		if node.material:
			node.material = _append_dither_pass(node.material)
			
	# Recurse children
	for child in node.get_children():
		_recursive_apply_dither(child)

func _append_dither_pass(material: Material) -> Material:
	if not material:
		return null
		
	# Duplicate the material to make it unique for this object/scene
	var new_mat = material.duplicate()
	
	# If it's a BaseMaterial3D or ShaderMaterial, it has next_pass
	if "next_pass" in new_mat:
		if new_mat.next_pass:
			# Check if the next pass is already our dither shader to avoid infinite stacking
			if _is_dither_material(new_mat.next_pass):
				pass # Already has it
			else:
				new_mat.next_pass = _append_dither_pass(new_mat.next_pass)
		else:
			new_mat.next_pass = _get_dither_next_pass_instance()
			
	return new_mat

func _is_dither_material(mat: Material) -> bool:
	if mat is ShaderMaterial and mat.shader:
		if mat.shader.resource_path.ends_with("Dither3DNextPass.gdshader"):
			return true
	return false

func _get_dither_next_pass_instance() -> Material:
	var base = load("res://addons/dither3d/materials/dither3d-nextpass-default.tres")
	if base:
		return base.duplicate()
	return null
