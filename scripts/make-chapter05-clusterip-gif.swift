// Run from repository root: swift -module-cache-path /tmp/ch05-swift-cache scripts/make-chapter05-clusterip-gif.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers
let width = 1600, height = 1200
let output = "images/articles/05/03-clusterip-traffic.gif"
let ink = NSColor(calibratedRed:0.12,green:0.20,blue:0.30,alpha:1)
let gray = NSColor(calibratedRed:0.40,green:0.46,blue:0.54,alpha:1)
let blue = NSColor(calibratedRed:0.12,green:0.36,blue:0.85,alpha:1)
let orange = NSColor(calibratedRed:0.82,green:0.37,blue:0.04,alpha:1)
func p(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:x,y:y)}
struct Stage {let section:String;let sentence:String;let color:NSColor;let paths:[[CGPoint]];let control:Bool}
let internalToB = [p(755,595),p(810,595),p(810,675),p(830,675),p(830,595),p(870,595)]
let bToPod = [p(1010,640),p(1010,835)]
let externalToC = [p(755,595),p(810,595),p(810,690),p(1200,690),p(1200,595),p(1250,595)]
let cToPod = [p(1400,640),p(1400,835)]
let ingressToOS = [p(750,915),p(780,915),p(780,660),p(570,660),p(570,640)]
let stages:[Stage] = [
 Stage(section:"설정 반영",sentence:"1. API Server가 Service와 EndpointSlice의 변경 정보를 각 Node의 kube-proxy에 전달합니다.",color:gray,paths:[[p(570,270),p(570,315),p(800,315),p(800,450),p(755,450)],[p(1010,270),p(1010,315),p(1200,315),p(1200,450),p(1150,450)],[p(1400,270),p(1400,315),p(1580,315),p(1580,450),p(1550,450)]],control:true),
 Stage(section:"설정 반영",sentence:"2. kube-proxy가 각 Node의 운영체제에 Service의 전달 규칙을 설정합니다.",color:gray,paths:[[p(570,485),p(570,550)],[p(1010,485),p(1010,550)],[p(1390,485),p(1390,550)]],control:true),
 Stage(section:"설정 반영",sentence:"3. Ingress Controller가 API Server에서 Ingress 규칙을 읽어 프록시 설정을 반영합니다.",color:gray,paths:[[p(350,235),p(310,235),p(310,915),p(390,915)]],control:true),
 Stage(section:"내부 호출",sentence:"4. 내부 클라이언트 Pod가 DNS로 확인한 ClusterIP 10.96.10.20:80으로 HTTP 요청을 보냅니다.",color:blue,paths:[[p(570,715),p(570,640)]],control:false),
 Stage(section:"내부 호출",sentence:"5. Node A의 전달 규칙이 Pod 1을 선택하고 목적지 주소를 10.244.1.5:80으로 바꿉니다.",color:blue,paths:[internalToB,bToPod],control:false),
 Stage(section:"내부 응답",sentence:"6. nginx Pod 1이 요청을 처리하고 기존 연결을 통해 내부 클라이언트 Pod에 응답합니다.",color:blue,paths:[Array(bToPod.reversed()),Array(internalToB.reversed()),[p(570,640),p(570,715)]],control:false),
 Stage(section:"외부 호출",sentence:"7. 외부 클라이언트가 공개 DNS로 확인한 AWS NLB 주소에 HTTP 요청을 보냅니다.",color:orange,paths:[[p(155,500),p(155,610)]],control:false),
 Stage(section:"외부 호출",sentence:"8. AWS NLB가 등록된 Ingress Controller Pod의 IP로 연결을 전달합니다.",color:orange,paths:[[p(280,660),p(300,660),p(300,915),p(390,915)]],control:false),
 Stage(section:"외부 호출",sentence:"9. Ingress 프록시가 호스트와 경로에 맞는 백엔드를 찾아 ClusterIP:80으로 별도 연결을 엽니다.",color:orange,paths:[ingressToOS],control:false),
 Stage(section:"외부 호출",sentence:"10. Node A의 전달 규칙이 Pod 2를 선택하고 목적지 주소를 10.244.2.8:80으로 바꿉니다.",color:orange,paths:[externalToC,cToPod],control:false),
 Stage(section:"외부 응답",sentence:"11. nginx Pod 2가 요청을 처리하고 백엔드 연결을 통해 Ingress 프록시에 응답합니다.",color:orange,paths:[Array(cToPod.reversed()),Array(externalToC.reversed()),Array(ingressToOS.reversed())],control:false),
 Stage(section:"외부 응답",sentence:"12. Ingress 프록시가 클라이언트 연결을 통해 AWS NLB를 거쳐 HTTP 응답을 돌려줍니다.",color:orange,paths:[[p(390,915),p(300,915),p(300,660),p(280,660)],[p(155,610),p(155,500)]],control:false)
]
var icons:[String:NSImage]=[:]
for (key,path) in ["node":"images/characters/refs/node-official.png","pod":"images/characters/refs/pod-official.png","svc":"images/characters/refs/svc.png","deploy":"images/characters/refs/deploy-unlabeled.png","ing":"images/characters/refs/ing.png","k8s":"images/k8s-icon-color.png"] {icons[key]=NSImage(contentsOfFile:path)!}
func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ fill:NSColor = .white){
 let r=NSBezierPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),xRadius:12,yRadius:12)
 fill.setFill();r.fill();NSColor(calibratedWhite:0.78,alpha:1).setStroke();r.lineWidth=1.5;r.stroke()
}
// Flipped graphics context gives all labels and route points the same top-left origin.
var labelBounds:[(CGRect,String)]=[]
func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ size:CGFloat=21,_ color:NSColor=ink,_ bold:Bool=false){
 let style=NSMutableParagraphStyle();style.alignment = .center
 let attrs:[NSAttributedString.Key:Any]=[.font:bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size),.foregroundColor:color,.paragraphStyle:style]
 let measured=(value as NSString).size(withAttributes:attrs)
 precondition(measured.width <= w+1,"Text exceeds reserved width: \(value) [\(measured.width) > \(w)]")
 labelBounds.append((CGRect(x:x+(w-measured.width)/2,y:y,width:measured.width,height:measured.height),value))
 (value as NSString).draw(in:CGRect(x:x,y:y,width:w,height:size*1.6),withAttributes:attrs)
}
func icon(_ key:String,_ x:CGFloat,_ y:CGFloat){icons[key]!.draw(in:CGRect(x:x,y:y,width:36,height:36),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}
func card(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ title:String,_ sub:String,_ key:String?=nil){
 box(x,y,w,h);if let key=key {icon(key,x+10,y+12)}
 text(title,x+(key == nil ? 5:48),y+14,w-(key == nil ? 10:55),21,ink,true);text(sub,x+8,y+53,w-16,18)
}
func route(_ pts:[CGPoint],_ color:NSColor,_ progress:CGFloat,_ square:Bool,_ showMarker:Bool=true){
 for (a,b) in zip(pts,pts.dropFirst()) {
  let segment=CGRect(x:min(a.x,b.x)-3,y:min(a.y,b.y)-3,width:abs(a.x-b.x)+6,height:abs(a.y-b.y)+6)
  for (bounds,label) in labelBounds {precondition(!segment.intersects(bounds),"Route crosses label: \(label)")}
 }
 let line=NSBezierPath();line.move(to:pts[0]);for pt in pts.dropFirst(){line.line(to:pt)}
 color.withAlphaComponent(0.18).setStroke();line.lineWidth=5;line.stroke()
 let lengths=zip(pts,pts.dropFirst()).map{hypot($1.x-$0.x,$1.y-$0.y)}
 var remaining=lengths.reduce(0,+)*progress
 let active=NSBezierPath();active.move(to:pts[0]);var tip=pts[0];var angle:CGFloat=0
 for i in 0..<lengths.count {
  let a=pts[i],b=pts[i+1];let fraction=min(1,max(0,remaining/lengths[i]))
  tip=p(a.x+(b.x-a.x)*fraction,a.y+(b.y-a.y)*fraction);active.line(to:tip);angle=atan2(b.y-a.y,b.x-a.x)
  remaining-=lengths[i];if remaining<=0 {break}
 }
 color.setStroke();active.lineWidth=5;active.stroke();color.setFill()
 let end=pts.last!,prev=pts[pts.count-2],endAngle=atan2(end.y-prev.y,end.x-prev.x)
 let head=NSBezierPath();head.move(to:end);head.line(to:p(end.x-14*cos(endAngle-0.45),end.y-14*sin(endAngle-0.45)));head.line(to:p(end.x-14*cos(endAngle+0.45),end.y-14*sin(endAngle+0.45)));head.close();head.fill()
 let marker=square ? NSBezierPath(rect:CGRect(x:tip.x-6,y:tip.y-6,width:12,height:12)) : NSBezierPath(ovalIn:CGRect(x:tip.x-8,y:tip.y-8,width:16,height:16));if showMarker {marker.fill()}
 _=angle
}
func background(_ idx:Int){
 NSColor.white.setFill();NSRect(x:0,y:0,width:width,height:height).fill()
 box(25,35,290,130,stages[idx].color.withAlphaComponent(0.07))
 text(stages[idx].section,35,55,270,26,stages[idx].color,true)
 text("단계 \(idx+1) / \(stages.count)",35,99,270,21)
 text("API에 저장되는 리소스",350,173,1220,16)
 for (x,w,title,sub,key) in [(350.0,390.0,"Deployment D1","replicas: 2 / 아래 Pod 두 개 유지","deploy"),(770.0,390.0,"Service S1 / ClusterIP","clusterip-service / 10.96.10.20:80","svc"),(1190.0,380.0,"Ingress I1","shop.example.com / → S1:80","ing")] {
  box(x,35,w,130,NSColor(calibratedRed:1,green:0.97,blue:0.90,alpha:1));icon(key,x+12,48)
  text(title,x+50,52,w-60,22,ink,true);text(sub,x+10,100,w-20,19)
 }
 box(350,195,1220,75,NSColor(calibratedRed:0.93,green:0.95,blue:1,alpha:1))
 text("Control Plane의 API Server / 선언된 리소스와 EndpointSlice 조회",360,211,1200,23,ink,true)
 
 box(330,325,1255,680,NSColor(calibratedRed:0.97,green:0.98,blue:1,alpha:1));icon("k8s",341,334)
 for (x,w,name) in [(365.0,410.0,"A"),(850.0,320.0,"B"),(1230.0,340.0,"C")] {
  box(x,360,w,625,NSColor(calibratedRed:0.93,green:0.97,blue:0.94,alpha:1));icon("node",x+10,367)
  text("Worker Node \(name)",x+45,373,w-55,23,ink,true)
  let cx=x+w/2;box(x+20,415,w-40,70,NSColor(calibratedRed:0.91,green:0.94,blue:1,alpha:1))
  text("kube-proxy",x+25,429,w-50,22,ink,true)
  box(x+20,550,w-40,90)
  text("운영체제의 패킷 처리",x+25,564,w-50,19,ink,true)
  text(name == "A" ? "ClusterIP를 선택한 Pod IP로 변환":"이 연결은 지정된 Pod IP로 전달",x+25,602,w-50,17)
  if name != "A" {
   let number=name == "B" ? "1":"2",ip=name == "B" ? "10.244.1.5:80":"10.244.2.8:80"
   card(x+20,835,w-40,95,"nginx Pod \(number)",ip,"pod")
   text("D1 복제본 / S1 대상",x+10,949,w-20,18)
  }
  _=cx
 }
 card(390,715,360,85,"내부 클라이언트 Pod","clusterip-service:80","pod")
 card(390,875,360,85,"Ingress Controller Pod","I1 적용 / 백엔드 S1:80 호출","pod")
 card(30,410,250,90,"외부 클라이언트","shop.example.com:80")
 card(30,610,250,100,"AWS LoadBalancer","Ingress 진입점 / NLB")
 text("NLB의 IP 대상 모드",20,737,280,18)
 text("Controller Pod IP로 전달",20,769,280,18)
 // The destination choice is made at A, not by kube-proxy on B or C.
 let target = (idx == 4 || idx == 5) ? "현재 연결의 대상: Pod 1" : ((idx == 9 || idx == 10) ? "현재 연결의 대상: Pod 2":"한 연결의 대상은 Pod 하나")
 text(target,850,790,720,20,idx<6 ? blue:orange,true)
 route([p(45,1035),p(105,1035)],gray,0.5,true);text("설정 조회와 반영",115,1021,250,20)
 route([p(440,1035),p(500,1035)],blue,0.5,false);text("내부 HTTP 요청과 응답",510,1021,330,20)
 route([p(930,1035),p(990,1035)],orange,0.5,false);text("외부 HTTP 요청과 응답",1000,1021,350,20)
}
let framesPerStage=20
let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,UTType.gif.identifier as CFString,stages.count*framesPerStage,nil)!
CGImageDestinationSetProperties(dest,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for (idx,stage) in stages.enumerated(){
 for f in 0..<framesPerStage {autoreleasepool {
  let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  let base=NSGraphicsContext(bitmapImageRep:bitmap)!
  NSGraphicsContext.saveGraphicsState()
  let ctx=base.cgContext;ctx.translateBy(x:0,y:CGFloat(height));ctx.scaleBy(x:1,y:-1)
  NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
  labelBounds.removeAll()
  background(idx)
  let progress=min(1,CGFloat(f)/14)
  for (i,points) in stage.paths.enumerated(){
   // Configuration updates happen independently; response segments are ordered.
   let fraction=stage.control ? progress : min(1,max(0,progress*CGFloat(stage.paths.count)-CGFloat(i)))
   if stage.control || fraction>0 {route(points,stage.color,fraction,stage.control,stage.control || (fraction < 1 || i == stage.paths.count-1))}
  }
  box(30,1070,1540,75,stage.color.withAlphaComponent(0.07))
  text(stage.sentence,45,1092,1510,24,stage.color,true)
  text("Fig 2. ClusterIP의 요청 전달: 설정 반영, 내부 호출과 외부 Ingress 호출",30,1163,1540,22)
  NSGraphicsContext.restoreGraphicsState()
  let image=bitmap.cgImage!
  let delay = f == framesPerStage-1 ? 1.0 : 0.09
  CGImageDestinationAddImage(dest,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:delay,kCGImagePropertyGIFUnclampedDelayTime:delay]] as CFDictionary)
 }}
 print("Rendered stage \(idx+1)/\(stages.count)")
}
precondition(CGImageDestinationFinalize(dest))
// Decode every encoded frame and save representative frames for visual review.
let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:output) as CFURL,nil)!
precondition(CGImageSourceGetCount(src)==stages.count*framesPerStage)
var duration=0.0
for i in 0..<CGImageSourceGetCount(src){
 let frame=CGImageSourceCreateImageAtIndex(src,i,nil)!
 precondition(frame.width==width && frame.height==height)
 let props=CGImageSourceCopyPropertiesAtIndex(src,i,nil)! as NSDictionary
 let gif=props[kCGImagePropertyGIFDictionary] as! NSDictionary
 duration += gif[kCGImagePropertyGIFDelayTime] as! Double
 if i%framesPerStage == framesPerStage-1 {
  let out=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"/tmp/ch05-stage-\(i/framesPerStage+1).png") as CFURL,UTType.png.identifier as CFString,1,nil)!
  CGImageDestinationAddImage(out,frame,nil);precondition(CGImageDestinationFinalize(out))
 }
}
print("Validated \(CGImageSourceGetCount(src)) frames, \(width)x\(height), \(duration) seconds; \(output)")
