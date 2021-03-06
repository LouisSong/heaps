import hxd.Math;
import h3d.pass.ScalableAO;
import hxd.Key in K;

class CustomRenderer extends h3d.scene.Renderer {

	public var sao : h3d.pass.ScalableAO;
	public var saoBlur : h3d.pass.Blur;
	public var mode = 0;
	public var hasMRT : Bool;
	var out : h3d.mat.Texture;

	public function new() {
		super();
		sao = new h3d.pass.ScalableAO();
		// TODO : use a special Blur that prevents bluring across depths
		saoBlur = new h3d.pass.Blur(3, 3, 2);
		sao.shader.sampleRadius	= 0.2;
		hasMRT = h3d.Engine.getCurrent().driver.hasFeature(MultipleRenderTargets);
		if( hasMRT )
			def = new h3d.pass.MRT(["color","depth","normal"],0,true);
	}

	override function render() {
		super.render();
		if(mode != 1) {
			var saoTarget = allocTarget("sao",0,false);
			setTarget(saoTarget);
			if( hasMRT )
				sao.apply(def.getTexture(1), def.getTexture(2), ctx.camera);
			else
				sao.apply(depth.getTexture(), normal.getTexture(), ctx.camera);
			resetTarget();
			saoBlur.apply(saoTarget, allocTarget("saoBlurTmp", 0, false));
			if( hasMRT ) h3d.pass.Copy.run(def.getTexture(0), null);
			h3d.pass.Copy.run(saoTarget, null, mode == 0 ? Multiply : null);
		}
	}

}

class Sao extends hxd.App {

	var wscale = 1.;
	var fui : h2d.Flow;

	function initMaterial( m : h3d.mat.MeshMaterial ) {
		m.mainPass.enableLights = true;
		if( !Std.instance(s3d.renderer,CustomRenderer).hasMRT ) {
			m.addPass(new h3d.mat.Pass("depth", m.mainPass));
			m.addPass(new h3d.mat.Pass("normal", m.mainPass));
		}
	}

	override function init() {

		fui = new h2d.Flow(s2d);
		fui.isVertical = true;
		fui.verticalSpacing = 5;

		var r = new hxd.Rand(Std.random(0xFFFFFF));

		var c = new CustomRenderer();
		s3d.renderer = c;

		var floor = new h3d.prim.Grid(40,40,0.25,0.25);
		floor.addNormals();
		floor.translate( -5, -5, 0);
		var m = new h3d.scene.Mesh(floor, s3d);
		initMaterial(m.material);
		m.material.color.makeColor(0.35, 0.5, 0.5);
		m.setScale(wscale);

		for( i in 0...100 ) {
			var box : h3d.prim.Polygon = new h3d.prim.Cube(0.3 + r.rand() * 0.5, 0.3 + r.rand() * 0.5, 0.2 + r.rand());
			box.unindex();
			box.addNormals();
			var p = new h3d.scene.Mesh(box, s3d);
			p.setScale(wscale);
			p.x = r.srand(3) * wscale;
			p.y = r.srand(3) * wscale;
			initMaterial(p.material);
			p.material.color.makeColor(r.rand() * 0.3, 0.5, 0.5);
		}
		s3d.camera.zNear = 0.1 * wscale;
		s3d.camera.zFar = 150 * wscale;

		s3d.lightSystem.ambientLight.set(0.5, 0.5, 0.5);
		var dir = new h3d.scene.DirLight(new h3d.Vector( -0.3, -0.2, -1), s3d);
		dir.color.set(0.5, 0.5, 0.5);

		var time = Math.PI * 0.25;
		var camdist = 6 * wscale;
		s3d.camera.pos.set(camdist * Math.cos(time), camdist * Math.sin(time), camdist * 0.5);
		new h3d.scene.CameraController(s3d).loadFromCamera();

		addSlider("Bias", 0, 0.3, function() return c.sao.shader.bias, function(v) c.sao.shader.bias = v);
		addSlider("Intensity", 0, 10, function() return c.sao.shader.intensity, function(v) c.sao.shader.intensity = v);
		addSlider("Radius", 0, 1, function() return c.sao.shader.sampleRadius, function(v) c.sao.shader.sampleRadius = v);
		addSlider("Blur", 0, 3, function() return c.saoBlur.sigma, function(v) c.saoBlur.sigma = v);

	}

	function addSlider( text, min : Float, max : Float, get : Void -> Float, set : Float -> Void ) {
		var f = new h2d.Flow(fui);

		f.horizontalSpacing = 5;

		var font = hxd.res.DefaultFont.get();
		var tf = new h2d.Text(font, f);
		tf.text = text;
		tf.maxWidth = 70;
		tf.textAlign = Right;

		var sli = new h2d.Slider(100, 10, f);
		sli.minValue = min;
		sli.maxValue = max;
		sli.value = get();

		var tf = new h2d.TextInput(font, f);
		tf.text = "" + hxd.Math.fmt(sli.value);
		sli.onChange = function() {
			set(sli.value);
			tf.text = "" + hxd.Math.fmt(sli.value);
			f.needReflow = true;
		};
		tf.onChange = function() {
			var v = Std.parseFloat(tf.text);
			if( Math.isNaN(v) ) return;
			sli.value = v;
			set(v);
		};
	}

	function reset() {
		while( s3d.numChildren > 0 )
			s3d.getChildAt(0).remove();
		s3d.dispose();
		init();
	}

	override function update( dt : Float ) {

		if(K.isPressed(K.BACKSPACE))
			reset();

		var r = Std.instance(s3d.renderer, CustomRenderer);
		if(K.isPressed(K.NUMBER_1))
			r.mode = 0;
		if(K.isPressed(K.NUMBER_2))
			r.mode = 1;
		if(K.isPressed(K.NUMBER_3))
			r.mode = 2;
		if(K.isPressed("B".code))
			r.saoBlur.passes = r.saoBlur.passes == 0 ? 3 : 0;
	}

	static function main() {
		new Sao();
	}

}
