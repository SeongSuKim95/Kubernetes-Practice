import AppKit
import ImageIO
import UniformTypeIdentifiers

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil)!
let original = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let iconSource = CGImageSourceCreateWithURL(URL(fileURLWithPath:"images/characters/refs/pod-official.png") as CFURL,nil)!
let podIcon = CGImageSourceCreateImageAtIndex(iconSource,0,nil)!
let width = 1120, height = 1152
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
 Stage(title:"1. The user declares a Pod template and three desired replicas in a Deployment.",detail:"",color:blue,path:[pt(590,110),pt(590,300)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"2. The Deployment Controller reads the Deployment specification through the API.",detail:"",color:purple,path:[pt(500,440),pt(400,440)],target:CGRect(x:86,y:326,width:304,height:68)),
 Stage(title:"3. The Deployment Controller requests a ReplicaSet with three desired replicas.",detail:"",color:purple,path:[pt(400,440),pt(500,440)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"4. The ReplicaSet Controller compares three desired replicas with zero Pod objects.",detail:"",color:orange,path:[pt(500,440),pt(400,440)],target:CGRect(x:86,y:400,width:304,height:73)),
 Stage(title:"5. The ReplicaSet Controller asks the API Server to create Pods A, B, and C.",detail:"",color:green,path:[pt(400,440),pt(500,440)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"6. The Scheduler checks the requirements of the unassigned Pods.",detail:"",color:purple,path:[pt(500,580),pt(455,580),pt(455,717),pt(400,717)],target:CGRect(x:75,y:655,width:325,height:125)),
 Stage(title:"7. The Scheduler selects a Node for each Pod and records the assignments via the API.",detail:"",color:purple,path:[pt(400,717),pt(455,717),pt(455,580),pt(500,580)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"8. The Kubelet reads the Pods assigned to its Node through the API.",detail:"",color:blue,path:[pt(710,355),pt(850,355)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"9. The Kubelet prepares the environment and asks the runtime to start the containers.",detail:"",color:green,path:[pt(1070,520),pt(1070,610)],target:CGRect(x:850,y:610,width:440,height:95)),
 Stage(title:"10. The runtime starts the containers in Pods A, B, and C.",detail:"",color:green,path:[pt(1070,705),pt(1070,775)],target:CGRect(x:850,y:775,width:440,height:125)),
 Stage(title:"11. The API Server marks Pod C for deletion after the user requests its removal.",detail:"",color:orange,path:[pt(590,110),pt(590,300)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"12. The Kubelet observes Pod C's deletion request through the API.",detail:"",color:orange,path:[pt(710,355),pt(850,355)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"13. The Kubelet asks the runtime to stop Pod C's container.",detail:"",color:orange,path:[pt(1070,520),pt(1070,610)],target:CGRect(x:850,y:610,width:440,height:95)),
 Stage(title:"14. The runtime stops Pod C's container through the graceful termination process.",detail:"",color:orange,path:[pt(1070,705),pt(1070,775)],target:CGRect(x:850,y:775,width:440,height:125)),
 Stage(title:"15. The Kubelet reports Pod C's termination and requests final removal of its API object.",detail:"",color:orange,path:[pt(850,355),pt(710,355)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"16. The API Server removes the terminated Pod C object.",detail:"",color:orange,path:[pt(605,600),pt(605,680)],target:CGRect(x:500,y:680,width:210,height:100)),
 Stage(title:"17. The ReplicaSet Controller observes two remaining active replicas.",detail:"",color:orange,path:[pt(500,440),pt(400,440)],target:CGRect(x:86,y:400,width:304,height:73)),
 Stage(title:"18. The ReplicaSet Controller requests Pod D to restore the desired replica count.",detail:"",color:green,path:[pt(400,440),pt(500,440)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"19. The Scheduler checks Pod D's resource requests and placement requirements.",detail:"",color:purple,path:[pt(500,580),pt(455,580),pt(455,717),pt(400,717)],target:CGRect(x:75,y:655,width:325,height:125)),
 Stage(title:"20. The Scheduler selects a Node for Pod D and records the assignment via the API.",detail:"",color:purple,path:[pt(400,717),pt(455,717),pt(455,580),pt(500,580)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"21. The selected Node's Kubelet reads Pod D's assignment and specification from the API.",detail:"",color:blue,path:[pt(710,355),pt(850,355)],target:CGRect(x:850,y:300,width:440,height:220)),
 Stage(title:"22. The Kubelet asks the runtime to start Pod D's container.",detail:"",color:green,path:[pt(1070,520),pt(1070,610)],target:CGRect(x:850,y:610,width:440,height:95)),
 Stage(title:"23. The runtime starts Pod D's container, bringing the running Pod count back to three.",detail:"",color:green,path:[pt(1070,705),pt(1070,775)],target:CGRect(x:850,y:775,width:440,height:125)),
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
let framesPerStage = 24
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
  NSColor.white.setFill();NSBezierPath(rect:CGRect(x:0,y:0,width:1400,height:1440)).fill()
  // Background is a square Quick Look rendering; draw at original coordinates.
  c.saveGState();c.translateBy(x:0,y:1400);c.scaleBy(x:1,y:-1);c.draw(original,in:CGRect(x:0,y:0,width:1400,height:1400));c.restoreGState()
  // Replace the static caption with a stage banner and GIF-specific caption.
  NSColor.white.setFill();NSBezierPath(rect:CGRect(x:0,y:960,width:1400,height:480)).fill()
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
  // API count includes the terminating object until final removal.
  let count: Int
  if index < 4 { count = 0 }
  else if index == 4 { count = min(3,Int(progress * 3.99)) }
  else if index < 15 { count = 3 }
  else if index == 15 { count = progress < 0.65 ? 3 : 2 }
  else if index == 16 { count = 2 }
  else if index == 17 { count = progress < 0.6 ? 2 : 3 }
  else { count = 3 }
  let running: Int
  if index < 9 {running=0}
  else if index == 9 {running=min(3,Int(progress*3.99))}
  else if index < 13 {running=3}
  else if index == 13 {running=progress < 0.8 ? 3 : 2}
  else if index < 22 {running=2}
  else {running=progress < 0.65 ? 2 : 3}
  NSColor(calibratedRed:0.94,green:0.96,blue:1,alpha:1).setFill()
  NSBezierPath(roundedRect:CGRect(x:35,y:965,width:1330,height:260),xRadius:12,yRadius:12).fill()
  for row in 0..<2 {
   let n=row == 0 ? count : running
   for slot in 0..<3 {
    let present=slot<n
    (present ? (row == 0 ? NSColor(calibratedRed:0.86,green:0.91,blue:1,alpha:1) : NSColor(calibratedRed:0.85,green:0.95,blue:0.9,alpha:1)) : NSColor(calibratedWhite:0.92,alpha:1)).setFill()
    NSBezierPath(roundedRect:CGRect(x:615+slot*240,y:1018+row*104,width:215,height:78),xRadius:10,yRadius:10).fill()
    if present {
     c.saveGState();c.translateBy(x:CGFloat(790+slot*240),y:CGFloat(1050+row*104));c.scaleBy(x:1,y:-1)
     c.draw(podIcon,in:CGRect(x:0,y:0,width:25,height:25));c.restoreGState()
    }
   }
  }
  c.saveGState();c.translateBy(x:0,y:1440);c.scaleBy(x:1,y:-1)
  label("Desired replicas: 3",55,1440-1006,23,NSColor.darkGray,true)
  label("Pod objects in API: \(count)",55,1440-1050,25,blue,true)
  label("Pods running on Nodes: \(running)",55,1440-1150,25,green,true)
  label("One container per Pod in this example",55,1440-1185,18,NSColor.darkGray)
  for row in 0..<2 {
   let n=row == 0 ? count : running
   for slot in 0..<3 {
    let present=slot<n
    let name=slot==2 && index>=17 ? "Pod D" : "Pod \(["A","B","C"][slot])"
    label(present ? name : "None",CGFloat(635+slot*240),CGFloat(1440-1057-row*104),22,present ? NSColor.darkGray : NSColor.gray,true)
    var state=""
    if present {
     if row==1 { state = slot==2 && index>=12 && index<=13 ? "Container stopping" : "Container running" }
     else if slot==2 && index>=10 && index<=15 {state="Deleting"}
     else if slot<2 && index>=9 {state="Node assigned"}
     else if index<6 || (index>=17 && index<19) {state="Awaiting Node"}
     else {state="Node assigned"}
    }
    label(state,CGFloat(635+slot*240),CGFloat(1440-1083-row*104),16,NSColor.darkGray)
   }
  }
  label(stage.title,45,1440-1290,26,stage.color,true)
  label("Fig 3. Pod creation and replica maintenance: API objects, scheduling, and container execution",45,1440-1410,20,NSColor.darkGray)
  c.restoreGState()
  for n in 0..<stages.count {
   (n == index ? stage.color : NSColor(calibratedWhite:0.85,alpha:1)).setFill()
   NSBezierPath(roundedRect:CGRect(x:45+n*57,y:1340,width:49,height:8),xRadius:4,yRadius:4).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  let image=bitmap.cgImage!
  CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
  if f == framesPerStage-1 {samples.append(image)}
 }
}
assert(CGImageDestinationFinalize(destination))
for (i,img) in samples.enumerated(){
 let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"/tmp/ch04-en-replica-stage-\(i+1).png") as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(d,img,nil);CGImageDestinationFinalize(d)
}
let check=CGImageSourceCreateWithURL(URL(fileURLWithPath:output) as CFURL,nil)!
print("GIF frames: \(CGImageSourceGetCount(check)); size: \(width)x\(height); loop: 55.2 seconds")
