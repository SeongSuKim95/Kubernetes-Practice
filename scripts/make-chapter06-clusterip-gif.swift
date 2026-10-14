// Render a temporary 1200 x 1200 SVG canvas (viewBox 0 0 1200 1200) with qlmanage -t -s 1200.
// Pass the full-width PNG path as the first argument; the renderer crops the 1200 x 770 artwork.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let width = 1200, height = 900
let output = "images/articles/06/03-clusterip-traffic.gif"
let ink = NSColor(calibratedRed:0.12,green:0.20,blue:0.30,alpha:1)
let gray = NSColor(calibratedRed:0.40,green:0.46,blue:0.54,alpha:1)
let blue = NSColor(calibratedRed:0.12,green:0.36,blue:0.85,alpha:1)
let orange = NSColor(calibratedRed:0.82,green:0.37,blue:0.04,alpha:1)
func p(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:x,y:y)}
struct Stage {let section:String;let sentence:String;let color:NSColor;let paths:[[CGPoint]];let control:Bool}
let purple = NSColor(calibratedRed:0.48,green:0.26,blue:0.72,alpha:1)
// Every connection attaches to the midpoint of a component edge.
let configA=[p(280,515),p(280,570)]
let incoming=[p(280,390),p(280,420),p(70,420),p(70,620),p(90,620)]
let target=[p(470,620),p(750,620)]
let stages:[Stage] = [
 Stage(section:"규칙 준비",sentence:"1. kube-proxy의 Node 전달 규칙 설정",color:gray,paths:[configA],control:true),
 Stage(section:"내부 요청",sentence:"2. 클라이언트 Pod의 Service IP로 요청",color:blue,paths:[incoming],control:false),
 Stage(section:"대상 선택",sentence:"3. 준비된 웹 Pod 선택과 목적지 주소 변환",color:blue,paths:[target],control:false),
 Stage(section:"응답",sentence:"4. 웹 Pod의 응답과 클라이언트 수신",color:blue,paths:[Array(target.reversed()),Array(incoming.reversed())],control:false)
]
let pngPath=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "/tmp/03-clusterip-topology.svg.png"
let pngSource=CGImageSourceCreateWithURL(URL(fileURLWithPath:pngPath) as CFURL,nil)!
let cropped=CGImageSourceCreateImageAtIndex(pngSource,0,nil)!.cropping(to:CGRect(x:0,y:0,width:1200,height:770))!
let backdrop=NSImage(cgImage:cropped,size:NSSize(width:1200,height:770))
var icons:[String:NSImage]=[:]
for (key,path) in ["node":"images/characters/refs/node-official.png","pod":"images/characters/refs/pod-official.png","svc":"images/characters/refs/svc.png","deploy":"images/characters/refs/deploy-unlabeled.png","ing":"images/characters/refs/ing.png","k8s":"images/k8s-icon-color.png"] {icons[key]=NSImage(contentsOfFile:path)!}
func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ fill:NSColor = .white){
 let r=NSBezierPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),xRadius:12,yRadius:12)
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
 labelBounds.append((CGRect(x:x+(w-measured.width)/2,y:y,width:measured.width,height:measured.height),value))
 (value as NSString).draw(in:CGRect(x:x,y:y,width:w,height:size*1.6),withAttributes:attrs)
}
func icon(_ key:String,_ x:CGFloat,_ y:CGFloat){icons[key]!.draw(in:CGRect(x:x,y:y,width:32,height:32),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}
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
 NSColor.white.setFill();NSRect(x:0,y:0,width:width,height:height).fill()
 backdrop.draw(in:CGRect(x:0,y:0,width:1200,height:770),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
}
func emphasis(_ idx:Int){
 for i in 0..<stages.count {
 let r=NSBezierPath(roundedRect:CGRect(x:40+i*280,y:878,width:264,height:6),xRadius:3,yRadius:3)
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
  box(30,795,1140,75,stage.color.withAlphaComponent(0.07))
  text(stage.sentence,45,820,1110,20,stage.color,true)
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
  let out=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"/tmp/ch06-clusterip-stage-\(i/framesPerStage+1)-\(i%framesPerStage == 0 ? "before":"after").png") as CFURL,UTType.png.identifier as CFString,1,nil)!
  CGImageDestinationAddImage(out,frame,nil);precondition(CGImageDestinationFinalize(out))
 }
}
print("Validated \(CGImageSourceGetCount(src)) frames, \(width)x\(height), \(duration) seconds; \(output)")
