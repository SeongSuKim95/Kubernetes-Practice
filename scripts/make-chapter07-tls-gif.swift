// Fig 7: local AppKit rendering, preserving chapter 7 typography.
// Chapter 7 native diagrams and animated HTTP paths. Run from repository root.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let width = 1200, height = 740
// Compress layout coordinates, while preserving font and icon sizes.
let verticalDensity: CGFloat = 0.82
let ink = NSColor(calibratedRed:0.12,green:0.20,blue:0.30,alpha:1)
let gray = NSColor(calibratedRed:0.40,green:0.46,blue:0.54,alpha:1)
let blue = NSColor(calibratedRed:0.12,green:0.36,blue:0.85,alpha:1)
let orange = NSColor(calibratedRed:0.82,green:0.37,blue:0.04,alpha:1)
let purple = NSColor(calibratedRed:0.48,green:0.26,blue:0.72,alpha:1)
let greenBG = NSColor(calibratedRed:0.93,green:0.97,blue:0.94,alpha:1)
let blueBG = NSColor(calibratedRed:0.93,green:0.96,blue:1,alpha:1)
let apiBG = NSColor(calibratedRed:1,green:0.98,blue:0.92,alpha:1)
func p(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:x,y:y)}
struct Stage {let sentence:String;let color:NSColor;let paths:[[CGPoint]];let control:Bool}
var icons:[String:NSImage]=[:]
for (key,path) in ["node":"images/characters/refs/node-official.png","pod":"images/characters/refs/pod-official.png","svc":"images/characters/refs/svc.png","deploy":"images/characters/refs/deploy-unlabeled.png","ing":"images/characters/refs/ing.png","k8s":"images/k8s-icon-color.png"] {icons[key]=NSImage(contentsOfFile:path)!}
func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ fill:NSColor = .white){
 let r=NSBezierPath(roundedRect:CGRect(x:x,y:y*verticalDensity,width:w,height:h*verticalDensity),xRadius:12,yRadius:12)
 fill.setFill();r.fill();NSColor(calibratedWhite:0.78,alpha:1).setStroke();r.lineWidth=1.5;r.stroke()
}
// Flipped graphics context gives all labels and route points the same top-left origin.
var labelBounds:[(CGRect,String)]=[]
func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ size:CGFloat=21,_ color:NSColor=ink,_ bold:Bool=false){
 let size: CGFloat = value.hasPrefix("Fig ") ? 23 : size >= 27 ? 26 : size >= 21 ? 21 : 18
 let style=NSMutableParagraphStyle();style.alignment = .center
 let attrs:[NSAttributedString.Key:Any]=[.font:bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size),.foregroundColor:color,.paragraphStyle:style]
 let measured=(value as NSString).size(withAttributes:attrs)
 precondition(measured.width <= w+1,"Text exceeds reserved width: \(value) [\(measured.width) > \(w)]")
 labelBounds.append((CGRect(x:x+(w-measured.width)/2,y:y*verticalDensity,width:measured.width,height:measured.height),value))
 (value as NSString).draw(in:CGRect(x:x,y:y*verticalDensity,width:w,height:size*1.6),withAttributes:attrs)
}
func icon(_ key:String,_ x:CGFloat,_ y:CGFloat){icons[key]!.draw(in:CGRect(x:x,y:y*verticalDensity,width:32,height:32),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}
// Center the icon/title group and the complete text block within each card.
func card(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ title:String,_ sub:String,_ key:String?=nil,_ extra:String?=nil){
 box(x,y,w,h)
 let titleWidth=(title as NSString).size(withAttributes:[.font:NSFont.boldSystemFont(ofSize:21)]).width
 let rowHeight:CGFloat=32, gap:CGFloat=7, subHeight:CGFloat=22
 let total=rowHeight+gap+subHeight+(extra == nil ? 0:28)
 let top=y+(h*verticalDensity-total)/2/verticalDensity
 let groupWidth=titleWidth+(key == nil ? 0:42)
 let left=x+(w-groupWidth)/2
 if let key=key {icon(key,left,top)}
 text(title,left+(key == nil ? 0:42),top+3/verticalDensity,titleWidth+1,21,ink,true)
 text(sub,x+8,top+(rowHeight+gap)/verticalDensity,w-16,18)
 if let extra=extra {text(extra,x+8,top+(rowHeight+gap+28)/verticalDensity,w-16,18)}
}
func route(_ originalPoints:[CGPoint],_ color:NSColor,_ progress:CGFloat,_ square:Bool,_ showMarker:Bool=true){
 let pts=originalPoints.map { CGPoint(x:$0.x,y:$0.y*verticalDensity) }
 for (a,b) in zip(pts,pts.dropFirst()) {
  let segment=CGRect(x:min(a.x,b.x)-3,y:min(a.y,b.y)-3,width:abs(a.x-b.x)+6,height:abs(a.y-b.y)+6)
  for (bounds,label) in labelBounds {precondition(!segment.intersects(bounds),"Route crosses label: \(label)")}
 }
 let line=NSBezierPath();if square {line.setLineDash([7,6],count:2,phase:0)};line.move(to:pts[0]);for pt in pts.dropFirst(){line.line(to:pt)}
 color.withAlphaComponent(0.18).setStroke();line.lineWidth=5;line.stroke()
 let lengths=zip(pts,pts.dropFirst()).map{hypot($1.x-$0.x,$1.y-$0.y)}
 var remaining=lengths.reduce(0,+)*progress
 let active=NSBezierPath();if square {active.setLineDash([7,6],count:2,phase:0)};active.move(to:pts[0]);var tip=pts[0];var angle:CGFloat=0
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

func blank(_ title:String){
 NSColor.white.setFill();NSRect(x:0,y:0,width:width,height:height).fill()

}
func node(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ name:String){
 box(x,y,w,h,greenBG);icon("node",x+12,y+10);text(name,x+55,y+16,230,21,ink,true)
}
func mark(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ color:NSColor){
 let r=NSBezierPath(roundedRect:CGRect(x:x,y:y*verticalDensity,width:w,height:h*verticalDensity),xRadius:12,yRadius:12)
 color.setStroke();r.lineWidth=3;r.stroke()
}

func render(_ draw:()->Void)->CGImage{
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let base=NSGraphicsContext(bitmapImageRep:bitmap)!
 NSGraphicsContext.saveGraphicsState();let ctx=base.cgContext
 ctx.translateBy(x:0,y:CGFloat(height));ctx.scaleBy(x:1,y:-1)
 NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
 labelBounds.removeAll();draw();NSGraphicsContext.restoreGraphicsState();return bitmap.cgImage!
}
func savePNG(_ img:CGImage,_ path:String){
 let dst=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(dst,img,nil);precondition(CGImageDestinationFinalize(dst))
}
let readSecret=[p(345,232.5),p(455,232.5)]
let loadSecret=[p(745,232.5),p(855,232.5)]
let applyTLS=[p(1000,295),p(1000,385),p(600,385),p(600,540)]
let external=[p(345,600),p(455,600)]
let internalPath=[p(745,600),p(855,600)]
let tlsStages:[Stage]=[
 Stage(sentence:"1. Controller가 Ingress의 참조에 따라 TLS Secret을 읽습니다.",color:gray,paths:[readSecret,loadSecret],control:true),
 Stage(sentence:"2. Controller가 진입점에 인증서와 개인 키를 설정합니다.",color:gray,paths:[applyTLS],control:true),
 Stage(sentence:"3. 브라우저가 사이트 이름을 알리며 TLS 연결을 시작합니다.",color:purple,paths:[external],control:false),
 Stage(sentence:"4. 진입점이 인증서를 제시하면 브라우저가 유효성을 확인합니다.",color:purple,paths:[Array(external.reversed())],control:false),
 Stage(sentence:"5. TLS 협상을 마치면 브라우저와 진입점 사이에 암호화된 연결이 준비됩니다.",color:blue,paths:[],control:false),
 Stage(sentence:"6. 브라우저가 암호화된 연결로 /web 요청을 보냅니다.",color:blue,paths:[external],control:false),
 Stage(sentence:"7. 진입점이 요청을 복호화하고 웹 Pod에 HTTP로 전달합니다.",color:orange,paths:[internalPath],control:false),
 Stage(sentence:"8. 웹 Pod가 처리한 응답을 HTTP로 진입점에 돌려줍니다.",color:orange,paths:[Array(internalPath.reversed())],control:false),
 Stage(sentence:"9. 진입점이 응답을 암호화해 브라우저에 돌려줍니다.",color:blue,paths:[Array(external.reversed())],control:false)
]
func lock(_ x:CGFloat,_ y:CGFloat){
 let y=y*verticalDensity
 blue.setStroke();blue.setFill()
 let shackle=NSBezierPath(roundedRect:CGRect(x:x+6,y:y,width:16,height:21),xRadius:8,yRadius:8);shackle.lineWidth=3;shackle.stroke()
 NSBezierPath(roundedRect:CGRect(x:x,y:y+13,width:28,height:22),xRadius:4,yRadius:4).fill()
}
func diagram(_ idx:Int){
 blank("인증서 설정과 HTTPS 요청 전달")
 box(25,80,1150,285,apiBG)
 text(idx<2 ? "사전 준비: 인증서 설정":"인증서 설정 완료",45,95,370,21,gray,true)
 card(55,170,290,125,"Ingress: web","tls.hosts: example.com","ing","secretName: example-com-tls")
 card(455,170,290,125,"TLS Secret","tls.crt / tls.key",nil,"example-com-tls")
 card(855,170,290,125,"Controller","HTTPS 진입점 설정")
 text("참조",350,187,100,18,gray);text("읽기",750,187,100,18,gray)
 box(25,425,1150,295,blueBG)
 text(idx<2 ? "요청 대기":idx<5 ? "TLS 연결 준비":"요청과 응답",45,440,280,21,idx<2 ? gray:blue,true)
 card(55,540,290,120,"브라우저",idx<3 ? "example.com":idx==3 ? "인증서 확인":"TLS 연결",nil)
 card(455,540,290,120,"HTTPS 진입점",idx<2 ? "인증서 설정 중":"TLS 종료 / web:80 선택",nil)
 card(855,540,290,120,"웹 Pod","HTTP :8080","pod")
 text("HTTPS :443",320,487,160,18,blue)
 text("HTTP",750,550,100,18,orange)
 if idx>=4 {
  lock(386,526)
  text("암호화 구간",80,676,450,18,blue)
  text("내부 HTTP 구간",720,676,420,18,orange)
 }
 if idx==0 {mark(455,170,290,125,gray)}
 if idx==1 {mark(455,540,290,120,gray)}
 if idx==3 {mark(55,540,290,120,purple)}
 if idx>=4 {mark(55,540,290,120,blue);mark(455,540,290,120,blue)}
 if idx==6 || idx==7 {mark(855,540,290,120,orange)}
 text("Fig 7. TLS Secret 설정과 HTTPS 요청의 전달",25,765,1150,23,ink,true)
}
let output="images/articles/07/04-ingress-tls.gif", framesPerStage=30
let dst=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,UTType.gif.identifier as CFString,tlsStages.count*framesPerStage,nil)!
CGImageDestinationSetProperties(dst,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for (idx,stage) in tlsStages.enumerated(){
 for f in 0..<framesPerStage {autoreleasepool {
  let img=render {
   diagram(idx)
   let progress=min(1,max(0,CGFloat(f-4)/19))
   for (i,points) in stage.paths.enumerated(){
    let fraction=min(1,max(0,progress*CGFloat(stage.paths.count)-CGFloat(i)))
    if fraction>0 {route(points,stage.color,fraction,stage.control,fraction<1)}
   }
   box(30,810,1140,60,stage.color.withAlphaComponent(0.07))
   text(stage.sentence,45,827,1110,20,stage.color,true)
   for i in 0..<tlsStages.count {
    let bar=NSBezierPath(roundedRect:CGRect(x:CGFloat(30+i*128),y:882*verticalDensity,width:112,height:5),xRadius:2,yRadius:2)
    (i==idx ? stage.color:NSColor(calibratedWhite:0.88,alpha:1)).setFill();bar.fill()
   }
  }
  CGImageDestinationAddImage(dst,img,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:f==framesPerStage-1 ? 1.5:0.08]] as CFDictionary)
 }}
 print("Rendered TLS stage \(idx+1)")
}
precondition(CGImageDestinationFinalize(dst))
let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:output) as CFURL,nil)!
precondition(CGImageSourceGetCount(source)==270)
for i in 0..<270 {
 let img=CGImageSourceCreateImageAtIndex(source,i,nil)!
 precondition(img.width==width && img.height==height)
 if i%framesPerStage==framesPerStage-1 {savePNG(img,"/tmp/ch07-tls-stage-\(i/framesPerStage+1).png")}
}
print("Validated 270 frames")
