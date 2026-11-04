// Run from the repository root: swift Scripts/export-icon-rasters.swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("App/ResetPlsIcon.icon/Assets/ResetPlsBlack.png")
let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!,0,nil)!
func render(_ size: Int, opaque: Bool, to url: URL) {
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    let c = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:alpha.rawValue)!
    let rect = CGRect(x:0,y:0,width:size,height:size)
    if opaque { c.setFillColor(CGColor(gray:0.025,alpha:1)); c.fill(rect) }
    c.interpolationQuality = .high
    c.draw(image,in:rect)
    let dest = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(dest,c.makeImage()!,nil)
    precondition(CGImageDestinationFinalize(dest))
}
let assets = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")
for size in [16,32,64,128,256,512,1024] { render(size,opaque:false,to:assets.appendingPathComponent("AppIcon-\(size).png")) }
render(1024,opaque:true,to:assets.appendingPathComponent("AppIcon-iOS-1024.png"))

render(128,opaque:true,to:root.appendingPathComponent("App/Assets.xcassets/AIUsageBrand.imageset/AIUsageBrand.png"))
render(256,opaque:true,to:root.appendingPathComponent("App/Assets.xcassets/AIUsageBrand.imageset/AIUsageBrand@2x.png"))
