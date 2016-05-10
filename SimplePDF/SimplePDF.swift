//
//  SimplePDF.swift
//  SimplePDF
//
//  Created by Nutchaphon Rewik on 13/01/2016.
//  Copyright Â© 2016 Nutchaphon Rewik. All rights reserved.
//

import UIKit

private enum SimplePDFCommand{
    
    case AddText(String)
    case AddAttributedText( NSAttributedString )
    case AddImage(UIImage)
    case AddLineSpace(CGFloat)
    case AddLineSeparator(height: CGFloat)
    case AddTable(rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>)
    
    case SetContentAlignment(ContentAlignment)
    case BeginNewPage
    
    case SetFont(UIFont)
}

public enum ContentAlignment{
    case Left, Center, Right
}

public class SimplePDF{
    
    /* States */
    private var commands: [SimplePDFCommand] = []
    
    /* Initialization */
    private let pageBounds: CGRect
    private let pageMargin: CGFloat
    
    public init(pageSize: CGSize, pageMargin: CGFloat = 20.0){
        
        pageBounds = CGRect(origin: CGPoint.zero, size: pageSize)
        self.pageMargin = pageMargin
    }
    
    
    /// Text will be drawn from the current font and alignment settings.
    ///
    /// If text is too long and doesn't fit in the current page.
    /// SimplePDF will begin a new page and draw remaining text.
    ///
    /// This process will be repeated untill there's no text left to draw.
    public func addText(text: String){
        commands += [ .AddText(text) ]
    }
    
    
    /// - Important: Font and Content alignment settings will be ignored.
    /// You have to manually add those attributes to attributed text yourself.
    public func addAttributedText( attributedText: NSAttributedString ){
        commands += [ .AddAttributedText(attributedText) ]
    }
    
    public func addImage(image: UIImage){
        commands += [ .AddImage(image) ]
    }
    
    public func addLineSpace(space: CGFloat){
        commands += [ .AddLineSpace(space) ]
    }
    
    public func addLineSeparator(height height: CGFloat = 1.0){
        commands += [ .AddLineSeparator(height: height) ]
    }
    
    public func addTable(rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>){
        commands += [ .AddTable(rowCount: rowCount, columnCount: columnCount, rowHeight: rowHeight, columnWidth: columnWidth, tableLineWidth: tableLineWidth, font: font, dataArray: dataArray) ]
    }
    
    public func setContentAlignment(alignment: ContentAlignment){
        commands += [ .SetContentAlignment(alignment) ]
    }
    
    public func beginNewPage(){
        commands += [ .BeginNewPage ]
    }
    
    public func setFont( font: UIFont ){
        commands += [ .SetFont(font) ]
    }
    
    /// - returns: drawing text rect
    private func drawText(text: String, font: UIFont, alignment: ContentAlignment, currentYoffset: CGFloat) -> CGRect{
        
        // Draw attributed text from font and paragraph style attribute.
        
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment{
        case .Left:
            paragraphStyle.alignment = .Left
        case .Center:
            paragraphStyle.alignment = .Center
        case .Right:
            paragraphStyle.alignment = .Right
        }
        
        let attributes: [String:NSObject] = [
            NSFontAttributeName: font,
            NSParagraphStyleAttributeName: paragraphStyle
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        return drawAttributedText(attributedText, currentYoffset: currentYoffset)
    }
    
    private func drawAttributedText( attributedText: NSAttributedString, currentYoffset: CGFloat) -> CGRect{
        
        var drawingYoffset = currentYoffset
        
        let currentText = CFAttributedStringCreateCopy(nil, attributedText as CFAttributedStringRef)
        let framesetter = CTFramesetterCreateWithAttributedString(currentText)
        var currentRange = CFRange(location: 0, length: 0)
        var done = false
        
        var lastDrawnFrame: CGRect!
        
        repeat{
            
            // Get the graphics context.
            let currentContext = UIGraphicsGetCurrentContext()!
            
            // Push state
            CGContextSaveGState(currentContext)
            
            // Put the text matrix into a known state. This ensures
            // that no old scaling factors are left in place.
            CGContextSetTextMatrix(currentContext, CGAffineTransformIdentity)
            
            // print("y offset: \t\(drawingYOffset)")
            
            let textMaxWidth = pageBounds.width - 2*pageMargin
            let textMaxHeight = pageBounds.height - pageMargin - drawingYoffset
            
            // print("drawing y offset: \t\(drawingYOffset)")
            // print("text max height: \t\(textMaxHeight)")
            
            // Create a path object to enclose the text.
            let frameRect = CGRect(x: pageMargin, y: drawingYoffset, width: textMaxWidth, height: textMaxHeight)
            let framePath = UIBezierPath(rect: frameRect).CGPath
            
            // Get the frame that will do the rendering.
            // The currentRange variable specifies only the starting point. The framesetter
            // lays out as much text as will fit into the frame.
            let frameRef = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
            
            // Core Text draws from the bottom-left corner up, so flip
            // the current transform prior to drawing.
            CGContextTranslateCTM(currentContext, 0, pageBounds.height + drawingYoffset - pageMargin)
            CGContextScaleCTM(currentContext, 1.0, -1.0)
            
            // Draw the frame.
            CTFrameDraw(frameRef, currentContext)
            
            // Pop state
            CGContextRestoreGState(currentContext)
            
            // Update the current range based on what was drawn.
            let visibleRange = CTFrameGetVisibleStringRange(frameRef)
            currentRange = CFRange(location: visibleRange.location + visibleRange.length , length: 0)
            
            // Update last drawn frame
            let constraintSize = CGSize(width: textMaxWidth, height: textMaxHeight)
            let drawnSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, visibleRange, nil, constraintSize, nil)
            lastDrawnFrame = CGRect(x: pageMargin, y: drawingYoffset, width: drawnSize.width, height: drawnSize.height)
            
            // print(suggestionSize)
            
            // If we're at the end of the text, exit the loop.
            // print("\(currentRange.location) \(CFAttributedStringGetLength(currentText))")
            if currentRange.location == CFAttributedStringGetLength(currentText){
                done = true
                // print("exit")
            }else{
                // begin a new page to draw text that is remaining.
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                drawingYoffset = pageMargin
                // print("begin a new page to draw text that is remaining")
            }
            
            
        }while(!done)
        
        return lastDrawnFrame
    }
    
    /// - returns: drawing image rect
    private func drawImage(image: UIImage, alignment: ContentAlignment, currentYoffset: CGFloat) -> CGRect{
        
        /* calculate the aspect size of image */
        
        let maxWidth = min( image.size.width, pageBounds.width )
        let maxHeight = min( image.size.height, pageBounds.height - currentYoffset )
        
        let wFactor = image.size.width / maxWidth
        let hFactor = image.size.height / maxHeight
        
        let factor = max(wFactor, hFactor)
        
        let aspectWidth = image.size.width / factor
        let aspectHeight = image.size.height / factor
        
        /* calculate x offset for rendering */
        let renderingXoffset: CGFloat
        switch alignment{
        case .Left:
            renderingXoffset = pageMargin
        case .Center:
            renderingXoffset = ( pageBounds.width - aspectWidth ) / 2.0
        case .Right:
            let right = pageBounds.width - pageMargin
            renderingXoffset =  right - aspectWidth
        }
        
        let renderingRect = CGRect(x: renderingXoffset, y: currentYoffset, width: aspectWidth, height: aspectHeight)
        
        // render image to current pdf context
        image.drawInRect(renderingRect)
        
        return renderingRect
    }
    
    private func drawLineSeparator(height height: CGFloat, currentYoffset: CGFloat) -> CGRect{
        
        let drawRect = CGRect(x: pageMargin, y: currentYoffset, width: pageBounds.width - 2*pageMargin, height: height)
        let path = UIBezierPath(rect: drawRect).CGPath
        
        // Get the graphics context.
        let currentContext = UIGraphicsGetCurrentContext()!
        
        // Set color
        UIColor.blackColor().setStroke()
        UIColor.blackColor().setFill()
        
        // Draw path
        CGContextAddPath(currentContext, path)
        CGContextDrawPath(currentContext, .FillStroke)
        
        // print(drawRect)
        
        return drawRect
    }
    
    private func drawTable(rowCount rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>, currentYoffset: CGFloat) -> CGRect{
        
        let height = (CGFloat(rowCount)*rowHeight)
        
        let drawRect = CGRect(x: pageMargin, y: currentYoffset, width: pageBounds.width - 2*pageMargin, height: height)
        
        UIColor.blackColor().setStroke()
        UIColor.blackColor().setFill()
        
        for i in 0...rowCount{
            let newOrigin = drawRect.origin.y + rowHeight*CGFloat(i)
            
            let from = CGPointMake(drawRect.origin.x, newOrigin)
            let to = CGPointMake(drawRect.origin.x + CGFloat(columnCount)*columnWidth, newOrigin)
            
            drawLineFromPoint(from, to: to, lineWidth: tableLineWidth)
        }
        
        for i in 0...columnCount{
            let newOrigin = drawRect.origin.x + columnWidth*CGFloat(i)
            
            let from = CGPointMake(newOrigin, drawRect.origin.y)
            let to = CGPointMake(newOrigin, drawRect.origin.y + CGFloat(rowCount)*rowHeight)
            
            drawLineFromPoint(from, to: to, lineWidth: tableLineWidth)
        }
        
        for i in 0..<rowCount{
            for j in 0...columnCount-1{
                let newOriginX = drawRect.origin.x + (CGFloat(j)*columnWidth)
                let newOriginY = drawRect.origin.y + ((CGFloat(i)*rowHeight))
                
                let frame = CGRectMake(newOriginX, newOriginY, columnWidth, rowHeight)
                drawTextInCell(frame, text: dataArray[i][j], font: font)
            }
        }
        
        return drawRect
    }
    
    private func drawLineFromPoint(from: CGPoint, to: CGPoint, lineWidth: CGFloat)
    {
        let context = UIGraphicsGetCurrentContext()!
        CGContextSetLineWidth(context, lineWidth)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let color = CGColorCreate(colorspace, [0.2, 0.2, 0.2, 1.0])
        
        CGContextSetStrokeColorWithColor(context, color)
        CGContextMoveToPoint(context, from.x, from.y)
        CGContextAddLineToPoint(context, to.x, to.y)
        
        CGContextStrokePath(context)
    }
    
    private func drawTextInCell(rect: CGRect, text: NSString, font: UIFont)
    {
        let fieldColor = UIColor.blackColor()
        
        let paraStyle = NSMutableParagraphStyle()
        
        let skew = 0.0
        
        let attributes: [String: AnyObject] = [
            NSForegroundColorAttributeName: fieldColor,
            NSParagraphStyleAttributeName: paraStyle,
            NSObliquenessAttributeName: skew,
            NSFontAttributeName: font
        ]
        
        let size = text.sizeWithAttributes(attributes)
        
        let x = (rect.size.width - size.width)/2
        let y = (rect.size.height - size.height)/2
        
        
        text.drawAtPoint(CGPointMake(rect.origin.x + x, rect.origin.y + y), withAttributes: attributes)
    }
    
    
    public func generatePDFdata() -> NSData{
        
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, pageBounds, nil)
        UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
        
        var currentYoffset = pageMargin
        var alignment = ContentAlignment.Left
        var font = UIFont.systemFontOfSize( UIFont.systemFontSize() )
        
        for command in commands{
            
            switch command{
            case let .AddText(text):
                let textFrame = drawText(text, font: font, alignment: alignment, currentYoffset: currentYoffset)
                currentYoffset = textFrame.origin.y + textFrame.height
                
            case let .AddAttributedText(attributedText):
                let textFrame = drawAttributedText(attributedText, currentYoffset: currentYoffset)
                currentYoffset = textFrame.origin.y + textFrame.height
                
            case let .AddImage(image):
                let imageFrame = drawImage(image, alignment: alignment, currentYoffset: currentYoffset)
                currentYoffset = imageFrame.origin.y + imageFrame.height
                
            case let .AddLineSeparator(height: height):
                let drawRect = drawLineSeparator(height: height, currentYoffset: currentYoffset)
                currentYoffset = drawRect.origin.y + drawRect.height
                
            case let .AddLineSpace(space):
                currentYoffset += space
                
            case let .AddTable(rowCount, columnCount, rowHeight, columnWidth, tableLineWidth, font, dataArray):
                let tableFrame = drawTable(rowCount: rowCount, columnCount: columnCount, rowHeight: rowHeight, columnWidth: columnWidth, tableLineWidth: tableLineWidth, font: font, dataArray: dataArray, currentYoffset: currentYoffset)
                currentYoffset = tableFrame.origin.y + tableFrame.height
                
            case let .SetContentAlignment(newAlignment):
                alignment = newAlignment
                
            case .BeginNewPage:
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                currentYoffset = pageMargin
                
            case let .SetFont(newFont):
                font = newFont
            }
            
        }
        
        UIGraphicsEndPDFContext()
        
        return pdfData
    }
    
}