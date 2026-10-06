// Run from repository root: swift -module-cache-path /tmp/ch05-swift-cache scripts/make-chapter05-dns-gif.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers
let width = 1600, height = 1200
let output = "images/articles/05/09-coredns-stable-entry.gif"
let ink = NSColor(calibratedRed:0.12,green:0.20,blue:0.30,alpha:1)
let gray = NSColor(calibratedRed:0.40,green:0.46,blue:0.54,alpha:1)
let blue = NSColor(calibratedRed:0.12,green:0.36,blue:0.85,alpha:1)
let orange = NSColor(calibratedRed:0.82,green:0.37,blue:0.04,alpha:1)
func p(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:x,y:y)}
struct Stage {let section:String;let sentence:String;let color:NSColor;let paths:[[CGPoint]];let control:Bool}
let purple = NSColor(calibratedRed:0.48,green:0.26,blue:0.72,alpha:1)
// Every connection attaches to the midpoint of a component edge.
let dnsOut=[p(240,610),p(240,650),p(375,650),p(375,690)]
let dnsToPod=[p(680,815),p(800,815),p(800,612.5),p(950,612.5)]
let httpOut=dnsOut
let httpToPod=[p(680,815),p(800,815),p(800,915),p(950,915)]
let syncDNS=[p(800,335),p(800,460),p(1210,460),p(1210,500)]
let syncRules=[p(800,335),p(800,460),p(555,460),p(555,500)]
let setRules=[p(555,580),p(555,650),p(375,650),p(375,690)]
let connectedBoxes=[CGRect(x:50,y:70,width:1500,height:265),CGRect(x:70,y:500,width:340,height:110),CGRect(x:430,y:500,width:250,height:80),CGRect(x:70,y:690,width:610,height:250),CGRect(x:950,y:500,width:520,height:225),CGRect(x:950,y:860,width:520,height:110)]
let midpoints=connectedBoxes.flatMap {r in [p(r.midX,r.minY),p(r.midX,r.maxY),p(r.minX,r.midY),p(r.maxX,r.midY)]}
for path in [dnsOut,dnsToPod,httpOut,httpToPod,syncDNS,syncRules,setRules] {
 precondition(midpoints.contains(path.first!) && midpoints.contains(path.last!),"Connection must use edge midpoints")
 for (a,b) in zip(path,path.dropFirst()) {
  for r in connectedBoxes {
   let alongHorizontal=a.y == b.y && (a.y == r.minY || a.y == r.maxY) && min(max(a.x,b.x),r.maxX)>max(min(a.x,b.x),r.minX)
   let alongVertical=a.x == b.x && (a.x == r.minX || a.x == r.maxX) && min(max(a.y,b.y),r.maxY)>max(min(a.y,b.y),r.minY)
   precondition(!alongHorizontal && !alongVertical,"Route must not run along a component border")
  }
 }
}
let stages:[Stage] = [
Stage(section:"Service 정보 반영",sentence:"1. CoreDNS가 API Server에서 web의 이름과 IP 정보를 받아 조회에 사용할 정보를 준비합니다.",color:gray,paths:[syncDNS],control:true),
Stage(section:"전달 규칙 준비",sentence:"2. kube-proxy가 API 정보를 받아 kube-dns와 web의 실제 Pod로 연결할 규칙을 설정합니다.",color:gray,paths:[syncRules,setRules],control:false),
Stage(section:"DNS 조회",sentence:"3. 클라이언트가 DNS용 Service인 kube-dns의 IP로 web의 주소를 묻습니다.",color:purple,paths:[dnsOut],control:false),
Stage(section:"CoreDNS에 전달",sentence:"4. Node의 전달 규칙이 kube-dns의 IP를 CoreDNS Pod의 IP로 바꾸어 조회를 전달합니다.",color:purple,paths:[dnsToPod],control:false),
Stage(section:"DNS 응답",sentence:"5. CoreDNS가 web의 Service IP를 찾아 조회를 보낸 클라이언트에 응답합니다.",color:purple,paths:[Array(dnsToPod.reversed()),Array(dnsOut.reversed())],control:false),
Stage(section:"웹 요청",sentence:"6. 클라이언트가 응답받은 web의 IP로 요청하면 Node의 규칙을 거쳐 웹 Pod에 도달합니다.",color:blue,paths:[httpOut,httpToPod],control:false),

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
func background(_ idx:Int,_ progress:CGFloat){
 let dnsReady = idx > 0 || progress >= 1
 let rulesReady = idx > 1 || (idx == 1 && progress >= 1)
 NSColor.white.setFill();NSRect(x:0,y:0,width:width,height:height).fill()
 let serviceIP="10.96.10.20"
 let webIP="10.244.3.8"
 let dnsIP="10.244.2.3"
 text("DNS 조회와 가상 IP를 통한 Pod 통신",30,15,1540,29,ink,true)
 box(50,70,1500,265,NSColor(calibratedRed:0.95,green:0.97,blue:1,alpha:1))
 icon("node",65,82);text("Control Plane / API Server가 제공하는 정보",110,85,1380,24,ink,true)
 // Two actual tables: stable Service addresses and the Pods selected behind them.
 for (x,title,left,right,rows) in [
 (75.0,"Service 이름과 가상 IP","Service 이름","가상 IP",[("kube-dns","10.96.0.10"),("web",serviceIP)]),
 (825.0,"Service와 실제 Pod의 매핑 정보","Service 이름","Pod IP와 포트",[("kube-dns",dnsIP+":53"),("web",webIP+":80")])] {
 text(title,x,130,680,21,ink,true)
 box(x,166,680,132)
 NSColor(calibratedRed:0.89,green:0.93,blue:0.99,alpha:1).setFill()
 NSRect(x:x+1,y:167,width:678,height:42).fill()
 let grid=NSBezierPath()
 for y in [210.0,254.0] {grid.move(to:p(x,y));grid.line(to:p(x+680,y))}
 grid.move(to:p(x+260,166));grid.line(to:p(x+260,298))
 NSColor(calibratedWhite:0.75,alpha:1).setStroke();grid.lineWidth=1;grid.stroke()
 text(left,x+5,176,250,19,ink,true);text(right,x+265,176,410,19,ink,true)
 for (i,row) in rows.enumerated(){let y=CGFloat(220+i*44);text(row.0,x+5,y,250,21);text(row.1,x+265,y,410,21)}
 }
 text("Deployment: coredns / web-app → 각 Pod 유지",75,307,1430,17,gray)
 for (x,y,w,h,name) in [(50.0,375.0,690.0,630.0,"A"),(900.0,375.0,620.0,380.0,"B"),(900.0,785.0,620.0,220.0,"C")] {
 box(x,y,w,h,NSColor(calibratedRed:0.93,green:0.97,blue:0.94,alpha:1));icon("node",x+15,y+15)
 text("Worker Node \(name)",x+60,y+21,w-80,25,ink,true)
 }
 card(70,500,340,110,"클라이언트 Pod","DNS 서버: 10.96.0.10","pod")
 card(430,500,250,80,"kube-proxy","규칙 설정 프로세스")
 box(70,690,610,250)
 text("Node 운영체제의 Service 전달 규칙",80,703,590,22,ink,true)
 if rulesReady {
 text("DNS 조회 전달 규칙 (kube-dns)",80,749,590,20,purple,true)
 text("10.96.0.10:53 → \(dnsIP):53",80,782,590,22,purple,true)
 text("웹 요청 전달 규칙 (web)",80,840,590,20,blue,true)
 text("\(serviceIP):80 → \(webIP):80",80,875,590,22,blue,true)
 text(idx == 1 ? "전달 규칙 반영 완료":"web IP: \(serviceIP)",80,910,590,18,gray)
 } else {
 text("아직 전달 규칙이 없습니다",80,797,590,23,gray)
 text(idx == 1 && progress >= 0.5 ? "kube-proxy가 받은 정보로 규칙 설정 중":"API 정보 반영 대기",80,875,590,19,gray)
 }
 box(950,500,520,225);icon("pod",965,512)
 text("CoreDNS Pod / \(dnsIP)",1010,515,450,23,ink,true)
 text("이름과 IP 대응 정보",975,558,470,21,ink,true)
 if dnsReady {
 text("web → \(serviceIP)",975,613,470,25,purple,true)
 if idx == 0 {text("이름과 IP 정보 반영 완료",975,677,470,18,gray)}
 } else {
 text("아직 조회 정보가 없습니다",975,613,470,23,gray)
 text("API에서 Service 정보 수신 중",975,677,470,18,gray)
 }
 card(950,860,520,110,"웹 Pod / app: web","IP: \(webIP):80","pod")
}
func emphasis(_ idx:Int){
 let regions:[CGRect]
 switch idx {
 case 0: regions=[CGRect(x:950,y:500,width:520,height:225)]
 case 1: regions=[CGRect(x:430,y:500,width:250,height:80),CGRect(x:70,y:690,width:610,height:250)]
 case 2: regions=[CGRect(x:70,y:500,width:340,height:110)]
 case 3,4: regions=[CGRect(x:950,y:500,width:520,height:225)]
 default: regions=[CGRect(x:950,y:860,width:520,height:110)]
 }
 for r in regions {let outline=NSBezierPath(roundedRect:r.insetBy(dx:-3,dy:-3),xRadius:14,yRadius:14);stages[idx].color.setStroke();outline.lineWidth=4;outline.stroke()}
 for i in 0..<stages.count {
 let r=NSBezierPath(roundedRect:CGRect(x:40+i*254,y:1153,width:238,height:6),xRadius:3,yRadius:3)
 (i==idx ? stages[idx].color:NSColor(calibratedWhite:0.88,alpha:1)).setFill();r.fill()
 }
}
let framesPerStage=30
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
  let progress=min(1,max(0,CGFloat(f-5)/18))
  background(idx,progress)
  emphasis(idx)
  for (i,points) in stage.paths.enumerated(){
   // Configuration updates happen independently; response segments are ordered.
   let fraction=stage.control ? progress : min(1,max(0,progress*CGFloat(stage.paths.count)-CGFloat(i)))
   if stage.control || fraction>0 {route(points,stage.color,fraction,stage.control,stage.control || (fraction < 1 || i == stage.paths.count-1))}
  }
  box(30,1070,1540,75,stage.color.withAlphaComponent(0.07))
  text(stage.sentence,45,1092,1510,22,stage.color,true)
  text("Fig 2. DNS 조회와 가상 IP를 통한 Pod 통신",30,1163,1540,22)
  NSGraphicsContext.restoreGraphicsState()
  let image=bitmap.cgImage!
  let delay = f == framesPerStage-1 ? 1.6 : 0.09
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
 if i%framesPerStage == 0 || i%framesPerStage == framesPerStage-1 {
  let out=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"/tmp/ch05-dns-stage-\(i/framesPerStage+1)-\(i%framesPerStage == 0 ? "before":"after").png") as CFURL,UTType.png.identifier as CFString,1,nil)!
  CGImageDestinationAddImage(out,frame,nil);precondition(CGImageDestinationFinalize(out))
 }
}
print("Validated \(CGImageSourceGetCount(src)) frames, \(width)x\(height), \(duration) seconds; \(output)")
