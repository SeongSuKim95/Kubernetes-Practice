import AppKit
import ImageIO
import UniformTypeIdentifiers

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil)!
let original = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let iconSource = CGImageSourceCreateWithURL(URL(fileURLWithPath:"images/characters/refs/pod-official.png") as CFURL,nil)!
let podIcon = CGImageSourceCreateImageAtIndex(iconSource,0,nil)!
let width = 1120, height = 1056
let scale: CGFloat = 0.8
struct Stage {
 let title: String
 let detail: String
 let color: NSColor
 let path: [CGPoint]
 let target: CGRect
}
func pt(_ x: Int, _ y: Int) -> CGPoint { CGPoint(x:x,y:y) }
let blue = NSColor(calibratedRed:0.12,green:0.36,blue:0.88,alpha:1)
let purple = NSColor(calibratedRed:0.48,green:0.22,blue:0.78,alpha:1)
let green = NSColor(calibratedRed:0.0,green:0.48,blue:0.34,alpha:1)
let orange = NSColor(calibratedRed:0.80,green:0.32,blue:0.03,alpha:1)
let stages = [
 Stage(title:"1. The Kubelet asks the runtime for the container's execution state.",detail:"",color:blue,path:[pt(1070,520),pt(1070,610)],target:CGRect(x:850,y:610,width:440,height:95)),
 Stage(title:"2. The runtime returns the container's execution state to the Kubelet.",detail:"",color:blue,path:[pt(1070,610),pt(1070,520)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"3. The Kubelet checks /startup to determine whether application startup is complete.",detail:"",color:purple,path:[pt(850,460),pt(820,460),pt(820,800),pt(850,800)],target:CGRect(x:850,y:775,width:440,height:125)),
 Stage(title:"4. After /startup succeeds, the Kubelet starts independent readiness and liveness checks.",detail:"",color:purple,path:[pt(850,800),pt(820,800),pt(820,460),pt(850,460)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"5. The Kubelet checks /ready to determine whether the application can receive requests.",detail:"",color:purple,path:[pt(850,460),pt(820,460),pt(820,800),pt(850,800)],target:CGRect(x:850,y:775,width:440,height:125)),
 Stage(title:"6. After three /ready failures, readiness becomes False while the container keeps running.",detail:"",color:purple,path:[pt(850,800),pt(820,800),pt(820,460),pt(850,460)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"7. The Kubelet reports readiness so the Pod can be excluded from new request targets.",detail:"",color:green,path:[pt(850,355),pt(710,355)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"8. The Kubelet checks /healthz independently of readiness check results.",detail:"",color:purple,path:[pt(850,460),pt(820,460),pt(820,800),pt(850,800)],target:CGRect(x:850,y:775,width:440,height:125)),
 Stage(title:"9. After three /healthz failures, the Kubelet determines that the container needs a restart.",detail:"",color:purple,path:[pt(850,800),pt(820,800),pt(820,460),pt(850,460)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"10. The Kubelet asks the runtime to stop the container and restart it under the Always policy.",detail:"",color:orange,path:[pt(1070,520),pt(1070,610)],target:CGRect(x:850,y:610,width:440,height:95)),
 Stage(title:"11. The runtime restarts the container within the same Pod.",detail:"",color:orange,path:[pt(1070,705),pt(1070,775)],target:CGRect(x:850,y:775,width:440,height:125)),
 Stage(title:"12. The Kubelet begins again with /startup after the new container starts.",detail:"",color:purple,path:[pt(850,460),pt(820,460),pt(820,800),pt(850,800)],target:CGRect(x:850,y:775,width:440,height:125)),
]

func label(_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ color:NSColor,_ bold:Bool=false){
 var fittedSize = size
 let available: CGFloat = (x >= 635 && y > 240 && y < 460) ? 205 : (x == 55 ? 505 : 1350 - x)
 var font = bold ? NSFont.boldSystemFont(ofSize:fittedSize) : NSFont.systemFont(ofSize:fittedSize)
 while (value as NSString).size(withAttributes:[.font:font]).width > available && fittedSize > 12 {
  fittedSize -= 0.5
  font = bold ? NSFont.boldSystemFont(ofSize:fittedSize) : NSFont.systemFont(ofSize:fittedSize)
 }
 (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:font,.foregroundColor:color])
}
let framesPerStage = 30
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,UTType.gif.identifier as CFString,stages.count*framesPerStage,nil)!
CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
var samples:[CGImage] = []
for (index,stage) in stages.enumerated(){
 for f in 0..<framesPerStage {
  let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  let gc=NSGraphicsContext(bitmapImageRep:bitmap)!
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=gc
  let c=gc.cgContext
  c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:scale,y:-scale)
  NSColor.white.setFill();NSBezierPath(rect:CGRect(x:0,y:0,width:1400,height:1320)).fill()
  // Background is a square Quick Look rendering; draw at original coordinates.
  c.saveGState();c.translateBy(x:0,y:1400);c.scaleBy(x:1,y:-1);c.draw(original,in:CGRect(x:0,y:0,width:1400,height:1400));c.restoreGState()
  // Replace the static caption with a stage banner and GIF-specific caption.
  NSColor.white.setFill();NSBezierPath(rect:CGRect(x:0,y:960,width:1400,height:360)).fill()
  stage.color.withAlphaComponent(0.06).setFill();NSBezierPath(roundedRect:stage.target,xRadius:12,yRadius:12).fill()
  let border=NSBezierPath(roundedRect:stage.target.insetBy(dx:3,dy:3),xRadius:10,yRadius:10);stage.color.setStroke();border.lineWidth=4;border.stroke()
  let progress=min(CGFloat(f)/16,1)
  let lengths=zip(stage.path,stage.path.dropFirst()).map { hypot($1.x-$0.x,$1.y-$0.y) }
  let total=lengths.reduce(0,+)
  let path=NSBezierPath();path.move(to:stage.path[0]);for p in stage.path.dropFirst(){path.line(to:p)}
  path.lineWidth=7;stage.color.withAlphaComponent(0.25).setStroke();path.stroke()
  var remaining=total*progress
  var tip=stage.path[0]
  var angle:CGFloat=0
  let active=NSBezierPath();active.move(to:tip)
  for j in 0..<lengths.count {
   let a=stage.path[j], b=stage.path[j+1]
   let fraction=min(remaining/lengths[j],1)
   tip=CGPoint(x:a.x+(b.x-a.x)*fraction,y:a.y+(b.y-a.y)*fraction)
   angle=atan2(b.y-a.y,b.x-a.x);active.line(to:tip)
   remaining-=lengths[j];if remaining<=0 {break}
  }
  active.lineWidth=7;stage.color.setStroke();active.stroke()
  let head=NSBezierPath();head.move(to:tip);head.line(to:CGPoint(x:tip.x-17*cos(angle-0.45),y:tip.y-17*sin(angle-0.45)));head.line(to:CGPoint(x:tip.x-17*cos(angle+0.45),y:tip.y-17*sin(angle+0.45)));head.close();stage.color.setFill();head.fill()
  for (x,color) in [(CGFloat(55),blue),(CGFloat(730),purple)] {
   let line=NSBezierPath();line.move(to:CGPoint(x:x,y:1000));line.line(to:CGPoint(x:x+95,y:1000));line.lineWidth=6;color.setStroke();line.stroke()
   let arrow=NSBezierPath();arrow.move(to:CGPoint(x:x+100,y:1000));arrow.line(to:CGPoint(x:x+83,y:991));arrow.line(to:CGPoint(x:x+83,y:1009));arrow.close();color.setFill();arrow.fill()
  }
  // Startup gate precedes two independent recurring probes.
  let activeProbe = (index==2 || index==3 || index==11) ? 0 : ((index==4 || index==5) ? 1 : ((index==7 || index==8) ? 2 : -1))
  let positions=[CGRect(x:45,y:1032,width:375,height:48),CGRect(x:565,y:1026,width:745,height:42),CGRect(x:565,y:1080,width:745,height:42)]
  for (i,r) in positions.enumerated() {
   (i==activeProbe ? purple.withAlphaComponent(0.14) : NSColor(calibratedWhite:0.96,alpha:1)).setFill()
   NSBezierPath(roundedRect:r,xRadius:8,yRadius:8).fill()
  }
  let branch=NSBezierPath();branch.move(to:CGPoint(x:420,y:1056));branch.line(to:CGPoint(x:490,y:1056));branch.line(to:CGPoint(x:490,y:1101));branch.line(to:CGPoint(x:560,y:1101));branch.move(to:CGPoint(x:490,y:1056));branch.line(to:CGPoint(x:490,y:1047));branch.line(to:CGPoint(x:560,y:1047));purple.setStroke();branch.lineWidth=2;branch.stroke()
  c.saveGState();c.translateBy(x:0,y:1320);c.scaleBy(x:1,y:-1)
  label("Kubelet health-check paths",45,1320-979,21,NSColor.darkGray,true)
  label("Runtime execution state",180,1320-1016,24,blue,true)
  label("Pod HTTP probes",855,1320-1016,24,purple,true)
  label("1. startupProbe /startup",60,1320-1066,22,purple,activeProbe==0)
  label("On success",430,1320-1129,13,NSColor.darkGray)
  label("2. readinessProbe /ready: ready for requests",580,1320-1057,22,purple,activeProbe==1)
  label("2. livenessProbe /healthz: restart needed?",580,1320-1111,22,purple,activeProbe==2)
  label("Repeat independently",1100,1320-1139,17,NSColor.darkGray)
  label(stage.title,45,1320-1190,24,stage.color,true)
  label("Fig 5. Kubelet checks: startup first, then repeated readiness and liveness checks",45,1320-1290,20,NSColor.darkGray)
  c.restoreGState()
  for n in 0..<stages.count {
   (n == index ? stage.color : NSColor(calibratedWhite:0.85,alpha:1)).setFill()
   NSBezierPath(roundedRect:CGRect(x:45+n*109,y:1230,width:98,height:8),xRadius:4,yRadius:4).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  let image=bitmap.cgImage!
  CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
  if f == framesPerStage-1 {samples.append(image)}
 }
}
assert(CGImageDestinationFinalize(destination))
for (i,img) in samples.enumerated(){
 let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"/tmp/ch04-en-two-paths-stage-\(i+1).png") as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(d,img,nil);CGImageDestinationFinalize(d)
}
let check=CGImageSourceCreateWithURL(URL(fileURLWithPath:output) as CFURL,nil)!
print("GIF frames: \(CGImageSourceGetCount(check)); size: \(width)x\(height); loop: 36 seconds")
