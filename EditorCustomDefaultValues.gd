# EditorCustomDefaultValues.gd
# Plugin strategy to ensure default values are only set when the node 
# is created by the user, and not when the node is instanced from a scene file.
#
# When a scene is loaded, we get the root node, so we traverse the scene tree
# and record the instance ID of each node. When a new node is added, we check
# if the instance ID is in the list of known nodes. If it is, we skip setting
# the default value. If it is not, we set the default value.
#
# Nodes are also added that are not children of the edited scene.


@tool
extends EditorPlugin

var current_scene_tree = null
var current_scene_root = null
var known_scenes = {}
var current_scene_nodes = {}
var undo_redo = null
var loading_scene = false
var node_added_connected: bool = false


func _record_scene_nodes(node: Node) -> void:
    var id = node.get_instance_id()
    current_scene_nodes[id] = "initialized"
    for child in node.get_children():
        _record_scene_nodes(child)

func _on_node_added(node: Node) -> void:
    var id = node.get_instance_id()
    #print(current_scene_nodes)
    if id in current_scene_nodes:
        return
    # Test if current_scene_root is an ancestor of node
    if not node.is_part_of_edited_scene():
        return
    print("Node added ", id)
    print("  name: ", node.get_name())
    print("")
    if node is TextEdit:
        current_scene_nodes[id] = "initializing"
        undo_redo.create_action("Set TextEdit scroll_fit_content_height to true", 0, node)
        undo_redo.add_do_property(node, "scroll_fit_content_height", true)
        undo_redo.add_undo_property(node, "scroll_fit_content_height", false)
        undo_redo.commit_action()
        current_scene_nodes[id] = "initialized"
    else:
        current_scene_nodes[id] = "initialized"
    

func _on_scene_changed(scene: Node) -> void:
    # Disconnect the previous scene's node_added signal
    if null != current_scene_tree:
        current_scene_tree.node_added.disconnect(_on_node_added)
    if null != current_scene_root:
        current_scene_root = null
    # Initialize the new scene
    print("Scene exploring")
    var scene_tree = get_tree()
    if scene_tree:
        current_scene_tree = scene_tree
        current_scene_nodes = known_scenes.get(scene.get_instance_id(), {})
        undo_redo = get_undo_redo()
        var scene_root = scene_tree.edited_scene_root
        current_scene_root = scene_root
        if scene_root:
            _record_scene_nodes(scene_root)
        else:
            print("Scene root not found")
        print("Scene explored")
        # All nodes in the scene are now recorded
        scene_tree.node_added.connect(_on_node_added)
        node_added_connected = true
    else:
        print("Scene tree not found")

func _enter_tree():
    # Initialization of the plugin goes here.
    print("EditorCustomDefaultValue editor plugin launched")
    #connect signal scene_changed to _detect_node_added
    scene_changed.connect(_on_scene_changed)

func _exit_tree():
    # Clean-up of the plugin goes here.
    if node_added_connected:
        scene_changed.disconnect(_on_scene_changed)
