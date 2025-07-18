#include "NWengineCore.h"


struct UiItems {
    UIItem* load;
    UIItem* reload;
    UIItem* slider;
    UIItem* slider2;
    UIItem* slider3;
    UIItem* slider4;

    UIItem* lab0;
    UIItem* labfps;
};
UiItems uiItems;
Camera* camC;
Texture3D      cubetex;
Texture        tex;
ComputeShader* compute;

static float elapsed = 0.0;
static ShaderIdentifier usedShader = ShaderTexturedDefaultID;
v3i    si  = {256,256,128};

void SetWin(UIWindow* win) {
	Camera*	   cam	= Camera::ActiveCamera;
	Transform* tr	= win->attachedObject->Get<Transform>();
	UIWindow*  uwin = win->attachedObject->Get<UIWindow>();
	v2f		   s;
	s = cam->GetSize();
	s.x *= 0.15;
	uwin->SetTitle("");
	uwin->SetSize(s);
	uwin->SetPosition({-cam->GetSize().x * 0.5f + s.x * 0.5f, 0.0});
	uwin->prop &= ~Window_Prop_ResizableXL;
	uwin->prop &= ~Window_Prop_ResizableYU;
	uwin->prop &= ~Window_Prop_Movable;

    UIItemLabel* lab = uwin->AddItem(UIItemType_Label, -1, 0);
    UISetLabel(lab, "Load: ");
    uiItems.load = uwin->AddItem(UIItemType_Checkbox, -1,1);
    lab = uwin->AddItem(UIItemType_Label, -1, 0);
    UISetLabel(lab, "Reload: ");
    uiItems.reload = uwin->AddItem(UIItemType_Checkbox, -1,1);
    lab = uwin->AddItem(UIItemType_Label, -1, 1);
    UISetLabel(lab, "Absobrption: ");
    uiItems.slider = uwin->AddItem(UIItemType_Slider,-1,1);
    UIGetSliderData(uiItems.slider)->maxx = 10.0;
    UIGetSliderData(uiItems.slider)->minn = 0.0;
    UIGetSliderData(uiItems.slider)->curPercent = 0.5;

    lab = uwin->AddItem(UIItemType_Label, -1, 1);
    UISetLabel(lab, "Power: ");
    uiItems.slider2 = uwin->AddItem(UIItemType_Slider,-1,1);
    UIGetSliderData(uiItems.slider2)->maxx = 10.0;
    UIGetSliderData(uiItems.slider2)->minn = 0.0;
    UIGetSliderData(uiItems.slider2)->curPercent = 1.0;

    lab = uwin->AddItem(UIItemType_Label, -1, 1);
    UISetLabel(lab, "Light Pos: ");
    uiItems.slider3 = uwin->AddItem(UIItemType_Slider,-1,1);
    UIGetSliderData(uiItems.slider3)->maxx =  3.0;
    UIGetSliderData(uiItems.slider3)->minn = -3.0;
    UIGetSliderData(uiItems.slider3)->curPercent = 0.0;

    lab = uwin->AddItem(UIItemType_Label, -1, 1);
    UISetLabel(lab, "Camera Pos: ");
    uiItems.slider4 = uwin->AddItem(UIItemType_Slider,-1,1);
    UIGetSliderData(uiItems.slider4)->maxx =  3.0;
    UIGetSliderData(uiItems.slider4)->minn = -3.0;
    UIGetSliderData(uiItems.slider4)->curPercent = 0.5;

    uiItems.lab0   = uwin->AddItem(UIItemType_Label, -1, 1);
    uiItems.labfps = uwin->AddItem(UIItemType_Label, -1, 1);
}

void LoadComputeAndDispatch() {
	ComputeShaderIdentifier id = "./assets/Noise.comp.shader";
	Loader<ComputeShader>	shaderl;
	compute = shaderl.LoadFromFileOrGetFromCache((void*)&id, id.c_str(), 0);
    compute->Use();
    compute->SetUniform3i("uDispatchSize", si);
    cubetex.Bind(16);
    cubetex.BindImageTex(0);
    compute->Dispatch(si);
    Context::NWMemoryBarrier(NWMemoryBarrierBit::SHADER_IMAGE_ACCESS_BARRIER_BIT);
}

static void Init() {
	Context::SetTitle("Sandbox");
	Context::EnableVSync();
	Scene& s = Scene::CreateNew("New Scene");
	s.MakeCurrent();
	GameObject& cam		  = s.AddObject("camobj");
	GameObject& uwin	  = s.AddObject("uiobj");
    GameObject& rndQuad   = s.AddObject("rndobj");
    UIWindow& w = uwin.Add<UIWindow>();
	camC				  = cam.AddComponent<Camera>();
	camC->Use();
	camC->SetClearColor(fVec4(0.2, 0.0, 1.0, 1.0));
	camC->ChangeOrthoWithMSAA(1080, 720, MSAAValue::NW_MSx8);
	camC->GetFbo()->GenDepthStencilBuffer();
    SetWin(&w);
    Sprite& spr = rndQuad.Add<Sprite,Transform>();
    spr.SetSize(camC->size);
    ShaderIdentifier ids = "./assets/CloudMarch.shader";
    spr.SetShader(ids);
    if (!spr.shader || spr.shader->_glID == 0)
        spr.SetShader(NW_DEFAULT_SHADER); 
    else 
        usedShader = ids;

	s.Start();
    UIColorScheme colorScheme = uiColorSchemePreset_Test;
    colorScheme.winRest = v4f(0.0,0.0,1.0,0.0);
    currentUIColorScheme = colorScheme;
	Renderer::currentRenderer->SetStretch({1.0, 1.0});

    cubetex._size = si;
    cubetex._GPUGen(0, TexChannelInfo::NW_RGBA);
    cubetex.SetEdgesBehaviour(TexEdge::NW_REPEAT);
    cubetex.SetMinFilter(TexMinFilter::NW_MIN_LINEAR);
    cubetex.SetMaxFilter(TexMaxFilter::NW_LINEAR);
    LoadComputeAndDispatch();

    TextureIdentifier tid = {"./assets/tex.png",1};
    TextureIdentifier* p = &tid;
    Image img;
    img.alpha = 1;
    img.LoadFromFile(tid.name.c_str(), 0);
    tex._size.x = img.width;
    tex._size.y = img.height;
    tex._hasMipMap = 1;
    tex._GPUGen(img.pixelBuffer, TexChannelInfo::NW_RGBA);
    img.Clean();
}

#define UpdateIfExists(sh,name,code) if (sh->GetUniformLoc(name) != -1) {code;}
static void UpdateUniforms() {
    Shader* sh = Scene::currentScene->GetGameObject("rndobj")->Get<Sprite>()->GetShader();
    sh->Use();
    UpdateIfExists(sh,"uRes",sh->SetUniform2f("uRes", Camera::ActiveCamera->size));
    UpdateIfExists(sh,"uTime",sh->SetUniform1f("uTime", elapsed));
    UpdateIfExists(sh,"uPerc",sh->SetUniform1f("uPerc", UIGetSliderValue(uiItems.slider)));
    UpdateIfExists(sh,"uPow",sh->SetUniform1f("uPow", UIGetSliderValue(uiItems.slider2)));
    UpdateIfExists(sh,"uLpos",sh->SetUniform1f("uLpos", UIGetSliderValue(uiItems.slider3)));
    UpdateIfExists(sh,"uCpos",sh->SetUniform1f("uCpos", UIGetSliderValue(uiItems.slider4)));
    UpdateIfExists(sh,"uNoise",sh->SetUniform1i("uNoise", Inputs::GetInputKeyPressed('N')));

    UpdateIfExists(sh,"uTex1",sh->SetUniform1i("uTex1",16));
    UpdateIfExists(sh,"uTex2",sh->SetUniform1i("uTex2",17));

    cubetex.Bind(16);
    tex.Bind(17);

    compute->Use();
    UpdateIfExists(compute,"uDispatchSize",compute->SetUniform3i("uDispatchSize", si));
}
#undef UpdateIfExists

static void Update() { 
    CheckboxData* d = UIGetCheckboxData(uiItems.reload);
    if (d->value || Inputs::GetInputOnKeyRelease('R')) {
        system("cls");
        Sprite* spr = Scene::currentScene->GetGameObject("rndobj")->Get<Sprite>();
        Shader* sh  = spr->shader;
        if (usedShader != ShaderTexturedDefaultID) {
            Shader::resList[usedShader].Clean();
            Shader* newsh = Loader<Shader>().LoadFromFile(usedShader.c_str(), &usedShader);
            if (newsh->_glID)
                spr->SetShader(newsh);
            else
                spr->SetShader(ShaderTexturedDefaultID);
        }
        d->value = 0;
        elapsed = 0.0;

        compute->Clean();
        LoadComputeAndDispatch();
    }
    d = UIGetCheckboxData(uiItems.load);
    if (d->value) {
        system("cls");
        Sprite* spr = Scene::currentScene->GetGameObject("rndobj")->Get<Sprite>();
        Shader* sh  = &Shader::resList[usedShader];
        std::string str = GetFile("Shader\0*.shader\0*.glsl\0*.frag");
        if (str.size() > 0) {
            if (sh->_identifier != ShaderTexturedDefaultID)
                sh->Clean();
            Shader* newsh = Loader<Shader>().LoadFromFile(str.c_str(), &str);
            if (newsh->_glID != 0)
                spr->SetShader(newsh);
            else 
                spr->SetShader(ShaderTexturedDefaultID);
            Scene::currentScene->GetFirstObjectWithComponent(UIWindowID)->Get<UIWindow>()->SetTitle(str.c_str());
            usedShader = str;
        }
            d->value = 0;

        compute->Clean();
        LoadComputeAndDispatch();
    }
    UpdateUniforms();
    UISetLabel(uiItems.lab0, std::to_string(UIGetSliderValue(uiItems.slider4)).c_str());
    UISetLabel(uiItems.labfps, ("FPS: " + std::to_string((int)NWTime::GetFPS())).c_str());
    elapsed += NWTime::GetDeltaTime();
}

static void Render() {
	(*Renderer::currentRenderer)(true);
}

int main() {
    Context::_glInfo.maxVersion = 4;
    Context::_glInfo.minVersion = 5;
	Context::WINDOW_WIDTH  = 900;
	Context::WINDOW_HEIGHT = 500;
	NWenginePushFunction(ON_MAIN_CALL_LOCATION::InitEnd, Init);
	NWenginePushFunction(ON_MAIN_CALL_LOCATION::FrameIntermediate, Render);
	NWenginePushFunction(ON_MAIN_CALL_LOCATION::FrameIntermediate, Update);
	NWengineInit();
	NWengineLoop();
	NWengineShutdown();
}
