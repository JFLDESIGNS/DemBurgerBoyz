extends RefCounted

static func build(game: Node) -> void:
 var root:=Node3D.new()
 root.name="CeilingFixtures"
 game.world.add_child(root)
 var steel:=StandardMaterial3D.new()
 steel.albedo_color=Color("62666B")
 steel.emission_enabled=true
 steel.emission=Color(.45,.34,.20)
 steel.emission_energy_multiplier=.08
 steel.metallic=.88
 steel.roughness=.22
 var ceiling=game._add_box(root,Vector3(4.8,.065,.92),Vector3(0,2.615,.85),Color.WHITE)
 ceiling.name="VisibleMetalCeiling"
 ceiling.material_override=steel
 var fascia=game._add_box(root,Vector3(4.8,.22,.035),Vector3(0,2.54,1.225),Color.WHITE)
 fascia.name="MetalWindowHeader"
 fascia.material_override=steel
 for x in [-1.8,-.6,.6,1.8]:
  var fixture:=Node3D.new()
  fixture.name="OverheadFixture"+str(root.get_child_count())
  root.add_child(fixture)
  fixture.position=Vector3(x,2.567,.95)
  var rim:=MeshInstance3D.new()
  var ring:=BoxMesh.new()
  ring.size=Vector3(.23,.027,.20)
  rim.scale=Vector3.ONE*.8
  rim.mesh=ring;rim.material_override=steel
  fixture.add_child(rim)
  var diffuser:=MeshInstance3D.new()
  diffuser.name="EmissiveDiffuser"
  var disk:=BoxMesh.new()
  disk.size=Vector3(.174,.012,.145)
  diffuser.scale=Vector3.ONE*.8
  diffuser.mesh=disk;diffuser.position.y=-.02
  var glow:=ShaderMaterial.new()
  glow.shader=preload("res://shaders/ceiling_lamp_glow.gdshader")
  diffuser.material_override=glow
  diffuser.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  fixture.add_child(diffuser)
  var cone:=MeshInstance3D.new()
  cone.name="VisibleLightCone"
  var volume:=CylinderMesh.new()
  volume.top_radius=.075;volume.bottom_radius=.34;volume.height=.85
  volume.radial_segments=48
  volume.cap_top=false;volume.cap_bottom=false
  cone.mesh=volume
  cone.position.y=-.47
  var haze:=ShaderMaterial.new()
  haze.shader=preload("res://shaders/ceiling_light_cone.gdshader")
  cone.material_override=haze
  cone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  fixture.add_child(cone)

  var light:=SpotLight3D.new()
  light.name="CeilingDownlight"
  fixture.add_child(light)
  light.position.y=-.045
  light.rotation_degrees.x=-90
  light.light_color=Color("FFCB83")
  light.light_energy=.85
  light.light_specular=.35
  light.spot_range=2.1;light.spot_angle=62
  light.spot_attenuation=1.3
  light.shadow_enabled=true
  light.shadow_bias=.04

static func taped_label(game: Node, parent: Node3D, words: String, width: float, at: Vector3) -> void:
 var root:=Node3D.new()
 root.name=words+"TapedLabel"
 parent.add_child(root)
 # Label geometry hugs the cylinder; text and tape share the same curved surface.
 root.position=Vector3(0,at.y,0)
 root.rotation_degrees.y=180
 var viewport:=SubViewport.new()
 viewport.name="LabelArtwork"
 viewport.size=Vector2i(768,256)
 viewport.transparent_bg=true
 viewport.disable_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 root.add_child(viewport)
 var paper:=Polygon2D.new()
 paper.polygon=PackedVector2Array([Vector2(0,22),Vector2(75,15),Vector2(154,20),Vector2(285,10),Vector2(490,18),Vector2(650,12),Vector2(768,24),Vector2(768,229),Vector2(632,239),Vector2(512,230),Vector2(370,242),Vector2(200,231),Vector2(0,239)])
 paper.color=Color("F2E2B8")
 viewport.add_child(paper)
 for x in [32,670]:
  var tape:=Polygon2D.new()
  tape.polygon=PackedVector2Array([Vector2(x+8,0),Vector2(x+60,3),Vector2(x+48,256),Vector2(x-8,250)])
  tape.color=Color(.74,.61,.36,.45)
  viewport.add_child(tape)
 var label:=Label.new()
 label.name="BoldLettering"
 label.text="SEASON" if words=="Seasoning" else words.to_upper()
 label.position=Vector2(80,20)
 label.size=Vector2(608,216)
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.add_theme_font_override("font",game.UiFontsScript.body_heavy)
 label.add_theme_font_size_override("font_size",88 if words=="Seasoning" else 128)
 label.add_theme_color_override("font_color",Color("392719"))
 viewport.add_child(label)
 var radius:=absf(at.z)
 var span:=minf(width/radius,2.7)
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 32:
  var u0:=float(i)/32.0
  var u1:=float(i+1)/32.0
  for uv in [Vector2(u0,0),Vector2(u0,1),Vector2(u1,1),Vector2(u0,0),Vector2(u1,1),Vector2(u1,0)]:
   var angle:float=(uv.x-.5)*span
   st.set_uv(uv)
   st.set_normal(Vector3(sin(angle),0,cos(angle)))
   st.add_vertex(Vector3(sin(angle)*radius,(.5-uv.y)*.042,cos(angle)*radius))
 var mesh:=MeshInstance3D.new()
 mesh.name="WrappedPaper"
 mesh.mesh=st.commit()
 var mat:=StandardMaterial3D.new()
 mat.albedo_texture=viewport.get_texture()
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.roughness=.86
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 mesh.material_override=mat
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(mesh)
