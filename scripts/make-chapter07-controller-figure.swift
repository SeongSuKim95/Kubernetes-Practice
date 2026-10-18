// Static Fig 2: local AppKit rendering, preserving chapter 7 typography.
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
let submit=[p(530,210),p(610,210)]
let observe=[p(725,270),p(725,350),p(285,350),p(285,547.5),p(330,547.5)]
let configure=[p(465,547.5),p(500,547.5)]
let incoming=[p(230,547.5),p(260,547.5),p(260,675),p(567.5,675),p(567.5,590)]
let forward=[p(635,547.5),p(800,547.5)]
func diagram(_ idx:Int){
 blank("클러스터 안의 Ingress 설정과 요청 전달")
 box(275,65,900,670,NSColor(calibratedWhite:0.985,alpha:1))
 box(295,85,860,225,apiBG);icon("node",310,98)
 text("Control Plane Node",350,106,340,21,ink,true)
 card(320,150,210,120,"Ingress","/web → web:80","ing")
 card(610,150,230,120,"API Server","선언 / 대상 정보")
 card(900,150,230,120,"Service: web","EndpointSlice","svc","10.244.2.8:8080")
 text("저장",535,165,70,18,gray)
 text("관찰",490,312,110,18,gray)
 box(295,390,415,325,greenBG);icon("node",310,402);text("Worker Node A",355,410,320,21,ink,true)
 box(315,450,345,190);icon("pod",327,460);text("Ingress Controller Pod",370,460,275,18,ink,true)
 card(330,505,135,85,"Controller","변경 확인")
 box(500,505,135,85)
 text("Ingress",505,519,125,18,ink,true)
 text("프록시",505,551,125,18,ink,true)

 box(760,390,395,325,greenBG);icon("node",775,402);text("Worker Node B",820,410,310,21,ink,true)
 card(800,490,310,115,"Pod","10.244.2.8:8080","pod")
 text("Deployment가 유지하는 Pod",785,630,350,18)
 card(20,490,210,115,"외부 클라이언트","example.com/web")
 text("HTTP",670,515,90,18,orange)
 if idx==0 {mark(610,150,230,120,gray)}
 if idx==1 {mark(330,505,135,85,gray)}
 if idx==2 {mark(500,505,135,85,gray)}
 if idx==3 || idx==5 {mark(500,505,135,85,orange)}
 if idx==4 {mark(800,490,310,115,orange)}
 if idx==6 {mark(20,490,210,115,orange)}
 text("Fig 2. 클러스터의 설정 반영과 실제 요청 경로",25,765,1150,23,ink,true)
}

// Static overview: independent configuration and application request paths.
let result=render {
 diagram(9)
 route(submit,gray,1,true,false)
 route(observe,gray,1,true,false)
 route(configure,gray,1,true,false)
 route(incoming,orange,1,false,false)
 route(forward,orange,1,false,false)
}
savePNG(result,"images/articles/07/02-ingress-controller-flow.png")
print("Rendered aligned static Fig 2")
