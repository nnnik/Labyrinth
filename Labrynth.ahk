#Include agl.ahk
#Include gl.ahk
#Include Labyrithsgdip.ahk
#NoTrayIcon
SetBatchlines,-1
SetMouseDelay,-1
CoordMode,Mouse,Screen
SetFormat,FloatFast,15.15
	Map:=[]
	Map.Insert([2,1,1,1,1,1,1,1,0,3])
	Map.Insert([1,0,0,0,1,0,0,1,0,1])
	Map.Insert([1,0,1,0,1,0,0,1,0,1])
	Map.Insert([1,0,1,1,1,1,1,1,0,1])
	Map.Insert([1,0,0,0,0,0,1,0,1,1])
	Map.Insert([1,0,1,1,1,0,1,0,1,0])
	Map.Insert([1,0,0,0,1,1,1,0,1,0])
	Map.Insert([1,1,1,1,1,0,1,0,1,0])
	Map.Insert([1,0,0,0,0,0,1,1,1,0])
	Map.Insert([1,1,0,1,1,1,1,0,1,1])
Game:=new Labrynth(Map)
Loop{
	Game.Player.FirstUpdate()
	MouseMove,% (A_ScreenWidth//2),% (A_ScreenHeight//2)
	DllCall("ShowCursor","uint",0)
	While (Game.Hwnd=WinActive("A")){
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT)
		glLoadIdentity()
		Game.Update()
		Game.Draw()
		DllCall("gdi32\SwapBuffers","UInt",Game.hDC)
	}
	DllCall("ShowCursor","uint",1)
	While !(Game.Hwnd=WinActive("A"))
		Continue
}


Class Labrynth{


	__new(map){
		Global
		aglInit()
		Gui,new
		Gui,+LastFound
		aglUseGui()
		this.HWND:=WinExist()
		this.hDC := DllCall("GetDC", "ptr", WinExist(), "ptr")
		glEnable(GL_TEXTURE_2D)
		glEnable(GL_DEPTH_TEST)
		DllCall("opengl32\glEnable","UInt",0xBE2) ;GL_BLEND 
		DllCall("opengl32\glBlendFunc","UInt",0x302,"UInt",0x303) ;enable transparent textures
		DllCall("opengl32\glShadeModel","UInt",0x1D01)
		DllCall("opengl32\glHint","UInt",0xC50,"UInt",0x1102) ;GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST
		DllCall("opengl32\glPolygonMode","UInt",0x408,"UInt",0x1B02) ;GL_FRONT_AND_BACK, GL_FILL
		glDepthFunc(GL_LEQUAL)
		glClearDepth(1.0)
		Gui,show,w800 h600,Test
		ResizeScene(0,0,800,600)
		this.Player := new Player(2,2)
		this.Boxlist := new Boxlist()
		this.Textures:={}
		this.Textures.Wall:=LoadTexture("Wall.jpg")
		this.Textures.Ground:=LoadTexture("Ground.png")
		this.Textures.Start:=CreateTextTexture("Start","AA0000FF")
		this.Textures.Goal:=CreateTextTexture("Goal","AA00FF00")
		this.map:=map
		this.List:=this.CreateRedraw()
		MouseMove,% (A_ScreenWidth//2),% (A_ScreenHeight//2)
	}

	UpdateUserInput(){
		static MouseMidX:=(A_ScreenWidth//2),MouseMidY:=(A_ScreenHeight//2)
		MouseGetPos,MouseX,MouseY
		MouseX-=MouseMidX
		MouseY-=MouseMidY
		MouseMove,% MouseMidX,% MouseMidY,1
		this.Player.RawMove(GetKeyState("D")-GetKeyState("A"),GetKeyState("W")-GetKeyState("S"),MouseX,MouseY)
	}
	
	Update(){
		this.UpdateUserInput()
		this.UpdateCollisions()
	}
	
	Draw()
	{
		this.Player.draw()
		glCallList(this.List)
		For X,YBoxLine in this.Map
		{
			For Y,Box in YBoxLine
				If IsFunc(Box.OnDraw)
			Box.Ondraw.(this,X,Y)
		}
	}
	
	CreateRedraw(){
	ListIndex := glGenLists(1)
    glNewList(ListIndex,0x1300) ;GL_COMPILE
	newmap:=[]
    For X,YBoxLine in this.Map
	{
		newYBoxLine:=[]
		For Y,Box in YBoxLine
			newYBoxLine.Insert(this.Boxlist[Box].(this,X,Y,this.Map,this.Textures))
		newmap.Insert(newYBoxLine)
	}
	glEndList()
	this.map:=newmap
	return ListIndex
	}
	
	
	
	UpdateCollisions(){
		static OldIndexX,OldIndexY
		IndexX:=Round(this.Player.X/2)
		IndexY:=Round(this.Player.Z/2)
		PX:=mod(this.Player.X+1,2)
		PY:=mod(this.Player.Z+1,2)
		If (IndexX!=OldIndexX||IndexY!=OldIndexY)
		{
			If IsFunc(this.map[IndexX,IndexY].OnPlayerCollideFirst)
				this.map[IndexX,IndexY].OnPlayerCollideFirst(this,IndexX,IndexY,this.Player)
			OldIndexX:=IndexX,OldIndexY:=IndexY
		}
		If IsFunc(this.map[IndexX,IndexY].OnPlayerCollideFirst)
			this.map[IndexX,IndexY].OnPlayerCollideFirst(this,IndexX,IndexY,this.Player)
		If (!this.map[IndexX,IndexY+1].collision&&((t:=PY+this.Player.Size-2)>0.000000001))
			this.Player.Z-=t,PY:=mod(this.Player.Z+1,2)
		Else If (!this.map[IndexX,IndexY-1].collision&&((t:=PY-this.Player.Size)<-0.000000001))
			this.Player.Z-=t,PY:=mod(this.Player.Z+1,2)
		If (!this.map[IndexX+1,IndexY].collision&&((t:=PX+this.Player.Size-2)>0.000000001))
			this.Player.X-=t,PX:=mod(this.Player.X+1,2)
		Else If (!this.map[IndexX-1,IndexY].collision&&((t:=PX-this.Player.Size)<-0.000000001))
			this.Player.X-=t,PX:=mod(this.Player.X+1,2)
	}
}

class Player{
	__new(x,Z){
		this.X:=X
		this.Z:=Z
		this.Y:=0.5
		this.RX:=0
		this.RY:=0
		this.Speed := 2
		this.Si:=0
		this.Co:=1
		this.size:=0.3
	}
	
	RawMove(X,Y,RX,RY){
		If RY
		{
		this.RY+=RY/4
		If (this.RY>90)
			this.RY:=90
		if (this.RY<-90)
			this.RY:=-90
		}
		If RX
		{
			this.RX+=RX/4
			this.si:=sin(this.RX/180*3.14159265359)
			this.co:=cos(this.RX/180*3.14159265359)
		}
		b:=0
		If t:=(X**2)+(Y**2)
		b:=(1/Sqrt(t))
		b*=((t:=(STMS()))-this.LastUpdate)
 		X:=X*b
		Y:=Y*b
		
		this.X+=X*this.co
		this.X+=Y*this.si
		this.Z+=X*-this.si
		this.Z+=Y*this.co
		this.LastUpdate:=t
	}
	Draw(){
		glRotatef(this.RY,1,0,0)
		glRotatef(this.RX,0,1,0)
		Gltranslatef(-this.X,-this.Y,this.Z)
	}
	FirstUpdate(){
		this.LastUpdate:=STMS()
	}
}


Class Boxlist{
	0(p*){
		return {collision:0,id:0}
	}
	1(x,y,map,textures){
		glBindTexture(0xDE1,textures.Wall)
		If !map[x,y+1]
			DrawWallFront(X,Y)
		If !map[x+1,y]
			DrawWallRight(X,Y)
		If !map[x,y-1]
			DrawWallBack(X,Y)
		If !map[x-1,y]
			DrawWallLeft(X,Y)
		glBindTexture(0xDE1,textures.Ground)
			DrawGround(X,Y)
		return {collision:1,id:1}
	}
	2(x,y,map,textures){
		glBindTexture(0xDE1,textures.Wall)
		If !map[x,y+1]
			DrawWallFront(X,Y)
		If !map[x+1,y]
			DrawWallRight(X,Y)
		If !map[x,y-1]
			DrawWallBack(X,Y)
		If !map[x-1,y]
			DrawWallLeft(X,Y)
		glBindTexture(0xDE1,textures.Ground)
			DrawGround(X,Y)
		this.Player.X:=X*2-1
		this.Player.Z:=Y*2-1
		return {collision:1,id:2,OnDraw:func("DisplayStart")}
	}
	3(x,y,map,textures){
		glBindTexture(0xDE1,textures.Wall)
		If !map[x,y+1]
			DrawWallFront(X,Y)
		If !map[x+1,y]
			DrawWallRight(X,Y)
		If !map[x,y-1]
			DrawWallBack(X,Y)
		If !map[x-1,y]
			DrawWallLeft(X,Y)
		glBindTexture(0xDE1,textures.Ground)
			DrawGround(X,Y)
		return {collision:1,id:3,OnPlayerCollideFirst:func("EndGame"),OnDraw:func("DisplayGoal")}
	}
	

}

DisplayGoal(this,x,y){
	glBindTexture(0xDE1,this.textures.Goal)
	X:=X*2
	Z:=(-Y)*2
	Gltranslatef(X,0,Z)
	vX:=X-this.Player.X,vZ:=Z+this.Player.Z
	vX/=Sqrt((vX**2)+(vZ**2))
	vZ/=abs(vZ)
	glRotatef(180-vZ*Acos(vX)/3.14*180,0,1,0)
	glBegin(0x07)
	glTexCoord2f(0.0, 0.0), glVertex3f(0,1,1)
	glTexCoord2f(1.0, 0.0), glVertex3f(0,1,-1)
	glTexCoord2f(1.0, 1.0), glVertex3f(0,-1,-1)
	glTexCoord2f(0.0, 1.0), glVertex3f(0,-1,1)
	glEnd()
	glRotatef(vZ*Acos(vX)/3.14*180-180,0,1,0)
	Gltranslatef(-X,0,-Z)
}

DisplayStart(this,x,y){
	glBindTexture(0xDE1,this.textures.Start)
	X:=X*2
	Z:=(-Y)*2
	Gltranslatef(X,0,Z)
	vX:=X-this.Player.X,vZ:=Z+this.Player.Z
	vX/=Sqrt((vX**2)+(vZ**2))
	vZ/=abs(vZ)
	glRotatef(180-vZ*Acos(vX)/3.14*180,0,1,0)
	glBegin(0x07)
	glTexCoord2f(0.0, 0.0), glVertex3f(0,1,1)
	glTexCoord2f(1.0, 0.0), glVertex3f(0,1,-1)
	glTexCoord2f(1.0, 1.0), glVertex3f(0,-1,-1)
	glTexCoord2f(0.0, 1.0), glVertex3f(0,-1,1)
	glEnd()
	glRotatef(vZ*Acos(vX)/3.14*180-180,0,1,0)
	Gltranslatef(-X,0,-Z)
}


DrawWallLeft(BlockX,BlockY,BlockSize=1){
glBegin(0x07)
X:=BlockX*2-1
Z:=(-BlockY)*2
glTexCoord2f(0.0, 0.0), glVertex3f(X,BlockSize,Z+BlockSize)
glTexCoord2f(1.0, 0.0), glVertex3f(X,BlockSize,Z-BlockSize)
glTexCoord2f(1.0, 1.0), glVertex3f(X,-BlockSize,Z-BlockSize)
glTexCoord2f(0.0, 1.0), glVertex3f(X,-BlockSize,Z+BlockSize)
glEnd()
}

DrawWallRight(BlockX,BlockY,BlockSize=1){
glBegin(0x07)
X:=BlockX*2+1
Z:=(-BlockY)*2
glTexCoord2f(0.0, 0.0), glVertex3f(X,BlockSize,Z-BlockSize)
glTexCoord2f(1.0, 0.0), glVertex3f(X,BlockSize,Z+BlockSize)
glTexCoord2f(1.0, 1.0), glVertex3f(X,-BlockSize,Z+BlockSize)
glTexCoord2f(0.0, 1.0), glVertex3f(X,-BlockSize,Z-BlockSize)
glEnd()
}

EndGame(p*)
{
	Msgbox Yay you did it.
	GoSub,GuiEscape
}

DrawWallBack(BlockX,BlockY,BlockSize=1){
glBegin(0x07)
X:=BlockX*2
Z:=(-BlockY)*2+1
glTexCoord2f(0.0, 0.0), glVertex3f(X+BlockSize,BlockSize,Z)
glTexCoord2f(1.0, 0.0), glVertex3f(X-BlockSize,BlockSize,Z)
glTexCoord2f(1.0, 1.0), glVertex3f(X-BlockSize,-BlockSize,Z)
glTexCoord2f(0.0, 1.0), glVertex3f(X+BlockSize,-BlockSize,Z)
glEnd()
}

DrawWallFront(BlockX,BlockY,BlockSize=1){
glBegin(0x07)
X:=BlockX*2
Z:=(-BlockY)*2-1
glTexCoord2f(0.0, 0.0), glVertex3f(X-BlockSize,BlockSize,Z)
glTexCoord2f(1.0, 0.0), glVertex3f(X+BlockSize,BlockSize,Z)
glTexCoord2f(1.0, 1.0), glVertex3f(X+BlockSize,-BlockSize,Z)
glTexCoord2f(0.0, 1.0), glVertex3f(X-BlockSize,-BlockSize,Z)
glEnd()
}

DrawGround(BlockX,BlockY,BlockSize=1)
{
glBegin(0x07)
X:=BlockX*2
Z:=(-BlockY)*2
glTexCoord2f(0.0, 0.0), glVertex3f(X-BlockSize,-BlockSize,Z+BlockSize)
glTexCoord2f(1.0, 0.0), glVertex3f(X+BlockSize,-BlockSize,Z+BlockSize)
glTexCoord2f(1.0, 1.0), glVertex3f(X+BlockSize,-BlockSize,Z-BlockSize)
glTexCoord2f(0.0, 1.0), glVertex3f(X-BlockSize,-BlockSize,Z-BlockSize)
glEnd()
}



ResizeScene(PosX,PosY,Width,Height,FieldOfView = 45.0,ClipNear = 0.001,ClipFar = 100.0)
{
DllCall("opengl32\glViewport","Int",PosX,"Int",PosY,"Int",Width,"Int",Height)
DllCall("opengl32\glMatrixMode","UInt",0x1701) ;GL_PROJECTION
DllCall("opengl32\glLoadIdentity")
MaxY := ClipNear * Tan(FieldOfView * 0.00872664626), MaxX := MaxY * (Width / Height), DllCall("opengl32\glFrustum","Double",0 - MaxX,"Double",MaxX,"Double",0 - MaxY,"Double",MaxY,"Double",ClipNear,"Double",ClipFar)
DllCall("opengl32\glMatrixMode","UInt",0x1700) ;GL_MODELVIEW
} ;Once again th to Uberi

GuiEscape:
GuiClose:
DllCall("ShowCursor","uint",1)
ExitApp



CreateTextTexture(Text,Color="FF000000",Filter = "Linear"){
	pToken:=gdip_Startup()
	pTex:=Gdip_CreateBitmap(800,800)
	G:=Gdip_GraphicsFromImage(pTex)
	Gdip_SetSmoothingMode(G, 4)
	Gdip_TextToGraphics(G, Text, "y250 w80p Centre c" . Color . "r4 s100","Arial",800,800)
	Gdip_ImageRotateFlip(pTex, 6)
	DllCall("gdiplus\GdipCreateHBITMAPFromBitmap","UInt",pTex,"UInt*",hTex,"UInt",0x00000000)
	Gdip_DeleteGraphics(G)
	DllCall("gdiplus\GdipDisposeImage","UInt",pTex)
	Gdip_Shutdown(pToken)
	If !hTex
		Return, 0
	VarSetCapacity(BitmapInfo,24,0)
	DllCall("GetObject","UInt",hTex,"UInt",24,"UInt",&BitmapInfo)
	Bits := NumGet(BitmapInfo,20)
	Width := NumGet(BitmapInfo,4)
	Height := NumGet(BitmapInfo,8)
	DllCall("opengl32\glGenTextures","Int",1,"UInt*",Texture)
	DllCall("opengl32\glBindTexture","UInt",0xDE1,"UInt",Texture) ;GL_TEXTURE_2D
	Linear := 0x2601, Nearest := 0x2600 ;GL_LINEAR, GL_NEAREST
	DllCall("opengl32\glTexParameteri","UInt",0xDE1,"UInt",0x2801,"Int",%Filter%) ;GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER. Set the minifying filter
	DllCall("opengl32\glTexParameteri","UInt",0xDE1,"UInt",0x2800,"Int",%Filter%) ;GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER. Set the magnification filter
	DllCall("opengl32\glTexImage2D","UInt",0xDE1,"Int",0,"Int",4,"Int",Width,"Int",Height,"Int",0,"UInt",0x80E1,"UInt",0x1401,"UInt",Bits) 
	DllCall("DeleteObject","UInt",hTex)
	Return, Texture
}

LoadTexture(Filename,Filter = "Linear")
{
 hGDIP := DllCall("LoadLibrary","Str","gdiplus")
 VarSetCapacity(Temp1,16,0), NumPut(1,Temp1), DllCall("gdiplus\GdiplusStartup","UInt*",pToken,"UInt",&Temp1,"UInt",0)
 If A_IsUnicode
  DllCall("gdiplus\GdipCreateBitmapFromFile","UInt",&Filename,"UInt*",pBitmap)
 Else
  FilenameLength := DllCall("MultiByteToWideChar","UInt",0,"UInt",0,"UInt",&Filename,"Int",-1,"UInt",0,"Int",0) << 1, VarSetCapacity(wFilename,FilenameLength,0), DllCall("MultiByteToWideChar","UInt",0,"UInt",0,"UInt",&Filename,"Int",-1,"UInt",&wFilename,"UInt",FilenameLength), DllCall("gdiplus\GdipCreateBitmapFromFile","UInt",&wFilename,"UInt*",pBitmap)
 DllCall("gdiplus\GdipCreateHBITMAPFromBitmap","UInt",pBitmap,"UInt*",hBitmap,"UInt",0x00000000)
 DllCall("gdiplus\GdipDisposeImage","UInt",pBitmap)
 DllCall("gdiplus\GdiplusShutdown","UInt",pToken)
 DllCall("FreeLibrary","UInt",hGDIP)
 If !hBitmap
  Return, 0
 VarSetCapacity(BitmapInfo,24,0), DllCall("GetObject","UInt",hBitmap,"UInt",24,"UInt",&BitmapInfo), Bits := NumGet(BitmapInfo,20),
Width := NumGet(BitmapInfo,4), Height := NumGet(BitmapInfo,8)
 DllCall("opengl32\glGenTextures","Int",1,"UInt*",Texture)
 DllCall("opengl32\glBindTexture","UInt",0xDE1,"UInt",Texture) ;GL_TEXTURE_2D
 Linear := 0x2601, Nearest := 0x2600 ;GL_LINEAR, GL_NEAREST
 DllCall("opengl32\glTexParameteri","UInt",0xDE1,"UInt",0x2801,"Int",%Filter%) ;GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER. Set the minifying filter
 DllCall("opengl32\glTexParameteri","UInt",0xDE1,"UInt",0x2800,"Int",%Filter%) ;GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER. Set the magnification filter
 DllCall("opengl32\glTexImage2D","UInt",0xDE1,"Int",0,"Int",4,"Int",Width,"Int",Height,"Int",0,"UInt",0x80E1,"UInt",0x1401,"UInt",Bits) 
 DllCall("DeleteObject","UInt",hBitmap)
 Return, Texture
} ;THX to Uberi


STMS() { ; System Time in 1/10000 MS / STMS() returns milliseconds elapsed since 16010101000000 UT
Static T1601                              ; By SKAN / 21-Apr-2014  
  DllCall( "GetSystemTimeAsFileTime", "Int64*",T1601)
Return T1601/1000000
} ;THX to SKAN