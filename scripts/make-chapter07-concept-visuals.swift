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
func classes(){
 blank("IngressClass: Ingress 선언과 담당 Controller의 연결")
 box(25,90,1150,655,NSColor(calibratedWhite:0.985,alpha:1))
 text("Kubernetes Cluster",45,105,300,21,ink,true)
 box(45,175,320,480,blueBG);text("Namespace: default",65,193,280,21,ink,true)
 text("클러스터 범위",450,193,300,21,ink,true)
 node(820,175,335,480,"Worker Node A")
 card(70,270,270,115,"Ingress: shop","class: public","ing")
 card(70,490,270,115,"Ingress: admin","class: internal","ing")
 card(455,270,285,115,"IngressClass","public")
 card(455,490,285,115,"IngressClass","internal")
 card(845,270,285,115,"Controller Pod","외부 공개용","pod")
 card(845,490,285,115,"Controller Pod","사내 접속용","pod")
 route([p(340,327.5),p(455,327.5)],blue,1,false,false)
 route([p(740,327.5),p(845,327.5)],blue,1,false,false)
 route([p(340,547.5),p(455,547.5)],purple,1,false,false)
 route([p(740,547.5),p(845,547.5)],purple,1,false,false)
 text("참조",375,290,70,18,blue)
 text("담당",745,290,75,18,blue)
 text("참조",375,510,70,18,purple)
 text("담당",745,510,75,18,purple)
 text("Fig 3. Namespace 안의 Ingress와 클러스터 범위의 IngressClass",25,790,1150,23,ink,true)
}
let configureIngress=[p(445,240),p(445,425)]
let configureProxy=[p(725,240),p(725,285),p(300,285),p(300,429.5),p(280,429.5)]
let proxyToRules=[p(175,462),p(175,525)]
let directIn=[p(145,240),p(145,310),p(30,310),p(30,585),p(70,585)]
let directOut=[p(280,585),p(310,585),p(310,710),p(600,710),p(600,435),p(760,435)]
// Use separate proxy ports: client traffic at the top midpoint, backend traffic at the right midpoint.
let ingressIn=[p(255,185),p(285,185),p(285,320),p(445,320),p(445,425)]
let ingressOut=[p(555,505),p(600,505),p(600,620),p(760,620)]
let stages:[Stage]=[
 Stage(sentence:"1. Controller가 Ingress 규칙을 프록시에 반영합니다.",color:gray,paths:[configureIngress],control:true),
 Stage(sentence:"2. kube-proxy가 Service 정보를 바탕으로 Node의 전달 규칙을 설정합니다.",color:gray,paths:[configureProxy,proxyToRules],control:true),
 Stage(sentence:"3. 클라이언트가 애플리케이션의 NodePort 30080으로 요청합니다.",color:blue,paths:[directIn],control:false),
 Stage(sentence:"4. Node의 전달 규칙이 요청을 웹 Pod 1의 8080번 포트로 보냅니다.",color:blue,paths:[directOut],control:false),
 Stage(sentence:"5. 웹 Pod 1의 응답이 기존 요청 경로를 따라 클라이언트에 돌아갑니다.",color:blue,paths:[Array(directOut.reversed()),Array(directIn.reversed())],control:false),
 Stage(sentence:"6. 클라이언트가 example.com을 Ingress 진입점의 IP로 찾습니다.",color:purple,paths:[],control:false),
 Stage(sentence:"7. 클라이언트가 호스트와 /web 경로를 담아 Ingress의 80번 포트로 요청합니다.",color:orange,paths:[ingressIn],control:false),
 Stage(sentence:"8. 프록시가 web Service를 선택하고 웹 Pod 2의 주소로 직접 요청합니다.",color:orange,paths:[ingressOut],control:false),
 Stage(sentence:"9. 웹 Pod 2의 응답이 프록시를 거쳐 클라이언트에 돌아갑니다.",color:orange,paths:[Array(ingressOut.reversed()),Array(ingressIn.reversed())],control:false)
]
func traffic(_ idx:Int,_ progress:CGFloat){
 blank("Service 직접 요청과 Ingress 경유 요청")
 box(300,65,860,200,apiBG);text("API Server에 저장된 선언",320,77,820,21,ink,true)
 card(320,120,250,120,"Ingress: web","example.com /web","ing")
 card(600,120,250,120,"Service: web","80 → 8080","svc","EndpointSlice: Pod 1, 2")
 card(880,120,250,120,"Deployment: web","replicas: 2","deploy")
 text("외부 클라이언트",35,85,220,21,ink,true)
 box(35,130,220,110,blueBG)
 text("브라우저 / curl",45,143,200,21,ink,true)
 text(idx < 5 ? "192.0.2.10:30080":"example.com:80",43,187,204,18,idx < 5 ? blue:orange)
 if idx >= 5 {
  text("이름 → 192.0.2.10",35,250,220,18,purple)
 }
 box(15,300,1165,425,NSColor(calibratedWhite:0.99,alpha:1))
 node(45,335,530,360,"Worker Node A")
 text("Node IP: 192.0.2.10",65,663,265,18)
 box(70,397,210,65);text("kube-proxy",78,410,194,21,ink,true)
 box(70,525,210,120,blueBG)
 text("Service 전달 규칙",77,538,196,21,ink,true)
 text((idx >= 2 || (idx == 1 && progress >= 0.85)) ? "NodePort: 30080":"설정 대기",78,576,194,18,blue)
 text((idx >= 2 || (idx == 1 && progress >= 0.85)) ? "→ 웹 Pod :8080":"",78,610,194,18,blue)
 box(335,425,220,160);icon("pod",345,438)
 text("Ingress",380,438,155,21,ink,true);text("Controller Pod",343,468,199,21,ink,true)
 text((idx >= 1 || (idx == 0 && progress >= 0.85)) ? "/web → web:80":"규칙 반영 중",345,512,195,18,orange)
 text("프록시 :80",345,548,195,21,orange,true)
 node(625,335,530,160,"Worker Node B")
 card(760,390,350,90,"웹 Pod 1","10.244.2.8:8080","pod")
 node(625,520,530,160,"Worker Node C")
 card(760,575,350,90,"웹 Pod 2","10.244.3.8:8080","pod")
 if idx == 0 {mark(335,425,220,160,gray)}
 if idx == 1 {mark(70,525,210,120,gray)}
 if idx == 3 || idx == 4 {mark(760,390,350,90,blue)}
 if idx == 7 || idx == 8 {mark(760,575,350,90,orange)}
 text("■ 설정 반영",40,738,240,18,gray)
 text("● NodePort 요청 / 응답",340,738,340,18,blue)
 text("● Ingress 요청 / 응답",750,738,370,18,orange)
 text("Fig 5. 같은 웹 Pod 집합으로 향하는 두 요청 경로",30,770,1140,23,ink,true)
}
func routing(){
 blank("호스트와 경로에 따른 Service 선택")
 box(25,80,350,140,blueBG);text("브라우저 요청",45,98,310,21,ink,true)
 text("example.com/web",45,142,310,21,blue,true)
 text("example.com/api/items",45,179,310,21,orange,true)
 box(465,80,710,140,apiBG);icon("ing",480,96)
 text("Ingress: web / host: example.com",535,98,620,21,ink,true)
 text("/web (Prefix) → web:80",490,142,650,21,blue)
 text("/api (Prefix) → api:80",490,179,650,21,orange)
 box(25,280,350,425,greenBG);icon("node",40,658);text("Worker Node A",85,666,260,21,ink,true)
 box(65,420,270,150);icon("pod",77,434)
 text("Ingress Controller",115,440,210,21,ink,true)
 text("프록시",85,480,230,21,ink,true)
 text("호스트 + 경로 비교",85,525,230,18)
 card(440,250,345,90,"Service: web","대상 선택 / app=web","svc")
 card(815,250,360,90,"Deployment: web","Pod 복제본 관리","deploy")
 node(460,350,695,110,"Worker Node B")
 card(825,365,310,80,"웹 Pod / app=web",":8080","pod")
 card(440,495,345,90,"Service: api","대상 선택 / app=api","svc")
 card(815,495,360,90,"Deployment: api","Pod 복제본 관리","deploy")
 node(460,595,695,110,"Worker Node C")
 card(825,610,310,80,"API Pod / app=api",":8080","pod")
 route([p(200,220),p(200,420)],blue,1,false,false)
 route([p(335,495),p(395,495),p(395,405),p(825,405)],blue,1,false,false)
 route([p(200,570),p(200,650),p(825,650)],orange,1,false,false)
 text("HTTP 요청",65,360,130,18,blue)
 text("/web",580,427,150,18,blue)
 text("/api/items",570,672,190,18,orange)
 text("Fig 6. 한 진입점에서 경로별 Service의 Pod로 전달하는 요청",25,790,1150,23,ink,true)
}
func overview(){
 blank("쇼핑몰 요청과 Ingress")
 box(260,70,915,250,apiBG)
 text("API Server에 저장된 선언",280,88,875,21,ink,true)
 card(300,155,270,120,"Ingress","요청 조건과 Service","ing")
 card(650,155,230,120,"Service","화면 제공용","svc")
 card(930,155,230,120,"Service","상품 조회용","svc")
 box(260,390,350,395,greenBG)
 icon("node",280,735);text("Worker Node A",325,738,260,21,ink,true)
 box(630,390,545,395,greenBG)
 icon("node",650,735);text("Worker Node B",705,738,435,21,ink,true)
 card(300,500,270,110,"Controller Pod","Ingress 프록시","pod")
 card(650,500,230,110,"Pod","상품 화면 제공","pod")
 card(930,500,230,110,"Pod","상품 이름과 가격 조회","pod")
 card(25,500,205,110,"브라우저","쇼핑몰 이용")
 text("규칙 반영",280,340,150,18,gray)
 text("대상 Pod",775,340,120,18,gray)
 text("대상 Pod",1055,340,120,18,gray)
 text("화면 요청",560,465,100,18,blue,true)
 text("상품 정보 조회 요청",700,665,330,21,orange,true)
 route([p(435,275),p(435,500)],gray,1,true,false)
 route([p(765,275),p(765,500)],gray,1,true,false)
 route([p(1045,275),p(1045,500)],gray,1,true,false)
 route([p(230,555),p(300,555)],gray,1,false,false)
 route([p(570,555),p(650,555)],blue,1,false,false)
 route([p(435,610),p(435,710),p(1045,710),p(1045,610)],orange,1,false,false)
 text("Fig 1. 쇼핑몰의 화면 요청과 상품 조회 요청의 분리",25,835,1150,23,ink,true)
}
func controllerFlow(){
 blank("선언의 반영과 실제 요청의 전달")
 box(25,85,1150,255,apiBG);text("설정 반영",45,102,180,21,gray,true)
 card(60,175,280,115,"Ingress 선언","호스트 / 경로 / Service","ing")
 card(460,175,280,115,"API Server","선언 저장")
 card(860,175,280,115,"Controller","프록시 설정 구성")
 text("저장",345,190,110,18,gray);text("변경 확인",745,190,110,18,gray)
 route([p(340,232.5),p(460,232.5)],gray,1,true,false)
 route([p(740,232.5),p(860,232.5)],gray,1,true,false)
 box(25,420,1150,290,blueBG);text("애플리케이션 요청",45,438,270,21,orange,true)
 card(60,530,280,115,"외부 클라이언트","example.com/web")
 card(460,530,280,115,"프록시","호스트 / 경로 비교")
 card(860,530,280,115,"웹 Pod","web의 준비된 대상","pod")
 text("HTTP 요청",345,548,110,18,orange);text("전달",745,548,110,18,orange)
 route([p(340,587.5),p(460,587.5)],orange,1,false,false)
 route([p(740,587.5),p(860,587.5)],orange,1,false,false)
 text("Fig 2. Controller의 설정 반영과 프록시의 요청 처리",25,790,1150,23,ink,true)
}
func serviceLink(){
 blank("Ingress에서 Service를 거쳐 Pod로 이어지는 참조")
 for x:CGFloat in [30,450,870]{box(x,100,300,595,apiBG)}
 icon("ing",45,120);text("Ingress",90,125,215,21,ink,true)
 icon("svc",465,120);text("Service: web",510,125,215,21,ink,true)
 icon("pod",885,120);text("웹 Pod",930,125,215,21,ink,true)
 text("host: example.com",45,180,270,18);text("path: /web",45,215,270,18)
 card(50,285,260,100,"service.name","web")
 card(470,285,260,100,"metadata.name","web")
 card(50,440,260,100,"service.port.number","80")
 card(470,440,260,100,"port → targetPort","80 → 8080")
 card(890,440,260,100,"애플리케이션 포트","8080")
 card(470,580,260,90,"selector","app: web")
 card(890,580,260,90,"labels","app: web")
 text("이름 참조",335,295,110,18,gray);text("포트 참조",335,450,110,18,gray)
 text("대상 포트",750,450,110,18,gray);text("Label 선택",750,590,110,18,gray)
 route([p(310,335),p(470,335)],gray,1,true,false)
 route([p(310,490),p(470,490)],gray,1,true,false)
 route([p(730,490),p(890,490)],gray,1,true,false)
 route([p(730,625),p(890,625)],gray,1,true,false)
 text("Fig 4. Service 이름과 포트, Pod Label의 연결",25,790,1150,23,ink,true)
}
func tlsFlow(){
 blank("인증서 설정과 HTTPS 요청 전달")
 box(25,80,1150,285,apiBG);text("인증서 설정",45,95,220,21,gray,true)
 card(55,170,290,125,"Ingress: web","tls.hosts: example.com","ing","secretName: example-com-tls")
 card(455,170,290,125,"TLS Secret","tls.crt / tls.key",nil,"example-com-tls")
 card(855,170,290,125,"Controller","HTTPS 진입점 설정")
 text("참조",350,187,100,18,gray);text("읽기",750,187,100,18,gray)
 route([p(345,232.5),p(455,232.5)],gray,1,true,false)
 route([p(745,232.5),p(855,232.5)],gray,1,true,false)
 box(25,425,1150,295,blueBG);text("요청 전달",45,440,200,21,orange,true)
 card(55,540,290,120,"브라우저","인증서 확인")
 card(455,540,290,120,"HTTPS 진입점","TLS 종료 / web:80 선택")
 card(855,540,290,120,"웹 Pod","HTTP :8080","pod")
 text("HTTPS :443",345,495,110,18,orange);text("HTTP",750,555,100,18,orange)
 route([p(345,600),p(455,600)],orange,1,false,false)
 route([p(745,600),p(855,600)],orange,1,false,false)
 text("Fig 7. TLS Secret 설정과 웹 Pod로의 요청 전달",25,790,1150,23,ink,true)
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
let dir="images/articles/07/"
if CommandLine.arguments.contains("--routing-only") {
 savePNG(render{routing()},dir+"07-ingress-routing.png")
 exit(0)
}
if !CommandLine.arguments.contains("--traffic-only") {
savePNG(render{overview()},dir+"01-service-ingress-overview.png")
if CommandLine.arguments.contains("--overview-only") { exit(0) }
// Fig 2 is generated by make-chapter07-controller-figure.swift.
savePNG(render{serviceLink()},dir+"03-ingress-service-link.png")
savePNG(render{tlsFlow()},dir+"04-ingress-tls.png")
savePNG(render{classes()},dir+"05-ingress-class.png")
savePNG(render{routing()},dir+"07-ingress-routing.png")
}
let output=dir+"06-service-ingress-traffic.gif"
let count=30
let dst=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,UTType.gif.identifier as CFString,stages.count*count,nil)!
CGImageDestinationSetProperties(dst,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for (idx,stage) in stages.enumerated(){
 for f in 0..<count {autoreleasepool {
  let img=render {
   let progress=min(1,max(0,CGFloat(f-4)/19))
   traffic(idx,progress)
   for (i,points) in stage.paths.enumerated(){
    let fraction=min(1,max(0,progress*CGFloat(stage.paths.count)-CGFloat(i)))
    if fraction>0 {route(points,stage.color,fraction,stage.control,fraction<1 || i==stage.paths.count-1)}
   }
   box(30,810,1140,60,stage.color.withAlphaComponent(0.07))
   text(stage.sentence,45,827,1110,20,stage.color,true)
   for i in 0..<stages.count {
    let r=NSBezierPath(roundedRect:CGRect(x:CGFloat(30+i*128),y:882*verticalDensity,width:112,height:5),xRadius:2,yRadius:2)
    (i==idx ? stage.color:NSColor(calibratedWhite:0.88,alpha:1)).setFill();r.fill()
   }
  }
  CGImageDestinationAddImage(dst,img,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:f == count-1 ? 1.5:0.08]] as CFDictionary)
 }}
 print("Rendered stage \(idx+1)")
}
precondition(CGImageDestinationFinalize(dst))
let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:output) as CFURL,nil)!
precondition(CGImageSourceGetCount(source)==stages.count*count)
for i in 0..<CGImageSourceGetCount(source){
 let img=CGImageSourceCreateImageAtIndex(source,i,nil)!
 precondition(img.width==width && img.height==height)
 if i%count==count-1 {savePNG(img,"/tmp/ch07-stage-\(i/count+1).png")}
}
print("Validated all \(stages.count*count) GIF frames and six diagrams")
