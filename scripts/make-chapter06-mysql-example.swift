// Chapter 7 native diagrams and animated HTTP paths. Run from repository root.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let width = 1200, height = 760
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
 let line=NSBezierPath();if square {line.setLineDash([7,6],count:2,phase:0)};line.move(to:pts[0]);for pt in pts.dropFirst(){line.line(to:pt)}
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

func blank(_ title:String){
 NSColor.white.setFill();NSRect(x:0,y:0,width:width,height:height).fill()

}
func node(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ name:String){
 box(x,y,w,h,greenBG);icon("node",x+12,y+10);text(name,x+55,y+16,230,21,ink,true)
}
func mark(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ color:NSColor){
 let r=NSBezierPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),xRadius:12,yRadius:12)
 color.setStroke();r.lineWidth=3;r.stroke()
}
func mysql(){
 blank("Headless Service의 응용 사례: 데이터베이스 복제")
 card(40,110,260,110,"애플리케이션","주문 저장 / 상품 조회")
 box(400,110,340,110,apiBG);icon("svc",412,124)
 text("Headless Service",455,125,270,21,ink,true)
 text("주 서버 전용 이름 → 주 서버 IP",410,167,320,18,purple)
 box(810,110,340,110,apiBG);icon("svc",822,124)
 text("일반 ClusterIP Service",865,125,270,21,ink,true)
 text("읽기용 공통 주소",820,167,320,18,blue)
 text("StatefulSet이 관리하는 데이터베이스 Pod",400,279,750,21,ink,true)
 node(400,335,340,235,"Worker Node A")
 node(810,335,340,235,"Worker Node B")
 card(420,420,300,100,"주 서버 Pod","변경 기록 / 읽기 처리","pod")
 card(830,420,300,100,"복제 서버 Pod","변경 사항 복제 / 읽기 처리","pod")
 text("주문 생성 / 저장",200,410,210,21,purple,true)
 text("주 서버 지정 / 쓰기",200,440,210,18,purple)
 text("상품 목록 조회 / 읽기",360,56,330,21,blue,true)
 text("주 서버 전용 이름으로 복제 연결",590,635,390,18,orange)
 route([p(170,220),p(170,470),p(420,470)],purple,1,false,false)
 route([p(170,110),p(170,90),p(980,90),p(980,110)],blue,1,false,false)
 route([p(980,220),p(980,260),p(1170,260),p(1170,470),p(1130,470)],blue,1,false,false)
 route([p(980,520),p(980,610),p(570,610),p(570,520)],orange,1,false,false)
 text("Fig 11. Headless Service의 응용 사례: 주 서버 지정과 데이터 복제",30,710,1140,23,ink,true)
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
savePNG(render{mysql()},"images/articles/06/12-mysql-headless-example.png")
