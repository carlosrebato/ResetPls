// Run from the ResetPls repository root.
import AppKit
let base = "docs/app-store-assets/interface-20261103"
let out = "docs/app-store-assets/store-20261103"
try FileManager.default.createDirectory(atPath:out,withIntermediateDirectories:true)
func color(_ hex:UInt32)->NSColor { NSColor(srgbRed:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1) }
func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ r:CGFloat,_ c:NSColor){c.setFill();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:r,yRadius:r).fill()}
func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ size:CGFloat,_ c:NSColor = .white,_ weight:NSFont.Weight = .semibold,_ align:NSTextAlignment = .left){let p=NSMutableParagraphStyle();p.alignment=align;p.lineSpacing=2; (s as NSString).draw(in:NSRect(x:x,y:y,width:w,height:600),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:c,.paragraphStyle:p])}
func pic(_ name:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat){let im=NSImage(contentsOfFile:base+"/"+name)!; im.draw(in:NSRect(x:x,y:y,width:w,height:h),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high.rawValue])}
func phone(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat){box(x-10,y-10,w+20,h+20,112,color(0x505257));box(x-5,y-5,w+10,h+10,108,color(0x222326));box(x,y,w,h,104,.black)}
for lang in ["es","en"] {
 for page in 1...3 {
  let ctx=CGContext(data:nil,width:1320,height:2868,bitsPerComponent:8,bytesPerRow:1320*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
  NSGraphicsContext.saveGraphicsState()
  ctx.translateBy(x:0,y:2868);ctx.scaleBy(x:1,y:-1)
  NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
  box(0,0,1320,2868,0,color(0x08090a))
  text("RESETPLS",100,95,1120,30,color(0x92959a),.medium)
  if page == 1 {
   text(lang == "es" ? "A este ritmo\n¿llegas al reset?" : "At this pace\nwill you make\nit to reset?",100,180,1130,lang == "es" ? 110 : 100)
   let x:CGFloat=190,y:CGFloat=670,w:CGFloat=940,h:CGFloat=2042
   phone(x-18,y-18,w+36,h+36)
   ctx.saveGState();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:88,yRadius:88).addClip()
   pic("\(lang)-amber-app.png",x,y,w,h)
   text("12:08",x+60,y+32,200,30,.white,.semibold)
   box(x+w/2-105,y+24,210,54,27,.black)
   box(x+w-115,y+38,62,27,8,.white)
   ctx.restoreGState()
  } else if page == 2 {
   text(lang == "es" ? "También desde\nla pantalla\nde bloqueo" : "From your\nLock Screen too",100,180,1130,108)
   let x:CGFloat=190,y:CGFloat=670,w:CGFloat=940,h:CGFloat=2042
   phone(x-18,y-18,w+36,h+36)
   ctx.saveGState();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:88,yRadius:88).addClip()
   let grad=NSGradient(colors:[color(0x152b30),color(0x294c4c),color(0x101c27)])!
   grad.draw(in:NSRect(x:x,y:y,width:w,height:h),angle:55)
   box(x+w/2-105,y+24,210,54,27,.black)
   text(lang == "es" ? "Martes, 3 de noviembre" : "Tuesday, November 3",x+30,y+170,w-60,44,.white,.medium,.center)
   pic("\(lang)-amber-lock-inline.png",x+170,y+240,600,56)
   text("12:08",x+20,y+310,w-40,240,.white,.thin,.center)
   pic("\(lang)-amber-lock-rectangular.png",x+62,y+h-540,516,228)
   pic("\(lang)-amber-lock-circular.png",x+w-290,y+h-540,228,228)
   for (symbol,xx) in [("flashlight.on.fill",x+90),("camera.fill",x+w-210)] {
    box(xx,y+h-205,120,120,60,NSColor.white.withAlphaComponent(0.12))
    if let im=NSImage(systemSymbolName:symbol,accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:44,weight:.medium).applying(.init(paletteColors:[.white]))) { im.isTemplate=false; im.draw(in:NSRect(x:xx+34,y:y+h-171,width:52,height:52),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil) }
   }
   box(x+w/2-130,y+h-24,260,7,4,.white);ctx.restoreGState()
  } else {
   text(lang == "es" ? "Widgets\npara elegir" : "Widgets\nto choose from",100,180,1130,110)
   pic("\(lang)-green-small.png",150,670,450,450)
   pic("\(lang)-red-small.png",720,670,450,450)
   pic("\(lang)-amber-medium.png",135,1205,1050,490.38)
   pic("\(lang)-red-large.png",160,1760,1000,1049.45)
  }
  NSGraphicsContext.restoreGraphicsState()
  let rep=NSBitmapImageRep(cgImage:ctx.makeImage()!)
  let path="\(out)/\(lang)-0\(page).png";try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
  print(path)
 }
}
