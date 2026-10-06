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
 Stage(title:"1. The Kubelet reports container state and readiness to the API Server.",detail:"",color:green,path:[pt(850,355),pt(710,355)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"2. The API Server stores the reported Pod status in etcd.",detail:"",color:green,path:[pt(605,600),pt(605,680)],target:CGRect(x:500,y:680,width:210,height:100)),
 Stage(title:"3. kubectl get pods requests Pods labeled app=web from the API Server.",detail:"",color:blue,path:[pt(590,110),pt(590,300)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"4. kubectl displays a table using the Pod information returned by the API Server.",detail:"",color:blue,path:[pt(590,300),pt(590,110)],target:CGRect(x:450,y:20,width:280,height:90)),
 Stage(title:"5. kubectl requests the Pod list and selects name and status.phase for output.",detail:"",color:purple,path:[pt(590,110),pt(590,300)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"6. kubectl displays status.phase from the response in the PHASE column.",detail:"",color:purple,path:[pt(590,300),pt(590,110)],target:CGRect(x:450,y:20,width:280,height:90)),
 Stage(title:"7. kubectl describe pod requests the Pod details and related events from the API Server.",detail:"",color:orange,path:[pt(590,110),pt(590,300)],target:CGRect(x:500,y:300,width:210,height:300)),
 Stage(title:"8. kubectl shows container state, Pod conditions, and events to explain why the Pod is unready.",detail:"",color:orange,path:[pt(590,300),pt(590,110)],target:CGRect(x:450,y:20,width:280,height:90)),
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
  NSColor(calibratedRed:0.94,green:0.96,blue:1,alpha:1).setFill()
  NSBezierPath(roundedRect:CGRect(x:35,y:965,width:1330,height:270),xRadius:12,yRadius:12).fill()
  c.saveGState();c.translateBy(x:0,y:1440);c.scaleBy(x:1,y:-1)
  let mode=index/2
  let headings=["The Kubelet reports status independently of kubectl commands.", "Terminal: Pod list", "Terminal: Pod phases from the API", "Terminal: selected details and events"]
  label(headings[mode],55,1440-1002,23,stage.color,true)
  var lines:[String]=[]
  if mode==0 {
   lines=["Pod: web-7c8d9f6b5d-d3e4f", "Pod phase: Running       Container state: Running", "Container ready: false   Pod Ready: False", "Restart count: 0         Readiness probe: HTTP 503"]
  } else if mode==1 {
   lines=["$ kubectl get pods -l app=web -o wide"]
   if index==3 { lines += ["NAME                    READY  STATUS   RESTARTS  AGE  IP          NODE", "web-7c8d9f6b5d-a1b2c     1/1    Running  0         5m   10.244.1.8  worker-1", "web-7c8d9f6b5d-d3e4f     0/1    Running  0         5m   10.244.2.9  worker-2", "web-7c8d9f6b5d-g5h6j     0/1    Pending  0         20s  <none>      <none>"] }
   else {lines += ["Requesting the Pod list from the API Server..."]}
  } else if mode==2 {
   lines=["$ kubectl get pods -l app=web -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'"]
   if index==5 { lines += ["NAME                    PHASE", "web-7c8d9f6b5d-a1b2c     Running", "web-7c8d9f6b5d-d3e4f     Running", "web-7c8d9f6b5d-g5h6j     Pending"] }
   else {lines += ["Requesting the Pod list from the API Server..."]}
  } else {
   lines=["$ kubectl describe pod web-7c8d9f6b5d-d3e4f"]
   if index==7 {lines += ["Containers: web    State: Running    Ready: False    Restart Count: 0", "Conditions:       PodScheduled: True    Initialized: True", "                  ContainersReady: False    Ready: False", "Events: Warning   Unhealthy   kubelet", "Readiness probe failed: HTTP probe failed with statuscode: 503"]}
   else {lines += ["Requesting Pod details and events from the API Server..."]}
  }
  for (lineNumber,line) in lines.enumerated() {
   let font=NSFont.monospacedSystemFont(ofSize:19,weight:.regular)
   (line as NSString).draw(at:CGPoint(x:55,y:CGFloat(1440-1042-lineNumber*29)),withAttributes:[.font:font,.foregroundColor:NSColor.darkGray])
  }
  label(stage.title,45,1440-1290,26,stage.color,true)
  label("Fig 4. Pod status: Kubelet reports, kubectl requests, and command output",45,1440-1410,20,NSColor.darkGray)
  c.restoreGState()
  for n in 0..<stages.count {
   (n == index ? stage.color : NSColor(calibratedWhite:0.85,alpha:1)).setFill()
   NSBezierPath(roundedRect:CGRect(x:45+n*164,y:1340,width:148,height:8),xRadius:4,yRadius:4).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  let image=bitmap.cgImage!
  CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
  if f == framesPerStage-1 {samples.append(image)}
 }
}
assert(CGImageDestinationFinalize(destination))
for (i,img) in samples.enumerated(){
 let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"/tmp/ch04-en-status-stage-\(i+1).png") as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(d,img,nil);CGImageDestinationFinalize(d)
}
let check=CGImageSourceCreateWithURL(URL(fileURLWithPath:output) as CFURL,nil)!
print("GIF frames: \(CGImageSourceGetCount(check)); size: \(width)x\(height); loop: 24 seconds")
