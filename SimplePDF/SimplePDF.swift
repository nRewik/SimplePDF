//
//  SimplePDF.swift
//  SimplePDF
//
//  Created by Nutchaphon Rewik on 13/01/2016.
//  Copyright Â© 2016 Nutchaphon Rewik. All rights reserved.
//

import UIKit

private enum SimplePDFCommand {
    
    case addText(String)
    case addAttributedText( NSAttributedString )
    case addImage(UIImage)
    case addLineSpace(CGFloat)
    case addLineSeparator(height: CGFloat)
    case addTable(rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>)
    
    case setContentAlignment(ContentAlignment)
    case beginNewPage
    
    case setFont(UIFont)
}

public enum ContentAlignment {
    case left, center, right
}

open class SimplePDF {
    
    /* States */
    fileprivate var commands: [SimplePDFCommand] = []
    
    /* Initialization */
    fileprivate let pageBounds: CGRect
    fileprivate let pageMargin: CGFloat
    
    public init(pageSize: CGSize, pageMargin: CGFloat = 20.0) {
        
        pageBounds = CGRect(origin: CGPoint.zero, size: pageSize)
        self.pageMargin = pageMargin
    }
    
    
    /// Text will be drawn from the current font and alignment settings.
    ///
    /// If text is too long and doesn't fit in the current page.
    /// SimplePDF will begin a new page and draw remaining text.
    ///
    /// This process will be repeated untill there's no text left to draw.
    open func addText(_ text: String) {
        commands += [ .addText(text) ]
    }
    
    
    /// - Important: Font and Content alignment settings will be ignored.
    /// You have to manually add those attributes to attributed text yourself.
    open func addAttributedText( _ attributedText: NSAttributedString) {
        commands += [ .addAttributedText(attributedText) ]
    }
    
    open func addImage(_ image: UIImage) {
        commands += [ .addImage(image) ]
    }
    
    open func addLineSpace(_ space: CGFloat) {
        commands += [ .addLineSpace(space) ]
    }
    
    open func addLineSeparator(height: CGFloat = 1.0) {
        commands += [ .addLineSeparator(height: height) ]
    }
    
    open func addTable(_ rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>) {
        commands += [ .addTable(rowCount: rowCount, columnCount: columnCount, rowHeight: rowHeight, columnWidth: columnWidth, tableLineWidth: tableLineWidth, font: font, dataArray: dataArray) ]
    }
    
    open func setContentAlignment(_ alignment: ContentAlignment) {
        commands += [ .setContentAlignment(alignment) ]
    }
    
    open func beginNewPage() {
        commands += [ .beginNewPage ]
    }
    
    open func setFont( _ font: UIFont ) {
        commands += [ .setFont(font) ]
    }
    
    /// - returns: drawing text rect
    fileprivate func drawText(_ text: String, font: UIFont, alignment: ContentAlignment, currentYoffset: CGFloat) -> CGRect {
        
        // Draw attributed text from font and paragraph style attribute.
        
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        }
        
        let attributes: [String:NSObject] = [
            NSFontAttributeName: font,
            NSParagraphStyleAttributeName: paragraphStyle
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        return drawAttributedText(attributedText, currentYoffset: currentYoffset)
    }
    
    fileprivate func drawAttributedText( _ attributedText: NSAttributedString, currentYoffset: CGFloat) -> CGRect {
        
        var drawingYoffset = currentYoffset
        
        let currentText = CFAttributedStringCreateCopy(nil, attributedText as CFAttributedString)
        let framesetter = CTFramesetterCreateWithAttributedString(currentText!)
        var currentRange = CFRange(location: 0, length: 0)
        var done = false
        
        var lastDrawnFrame: CGRect!
        
        repeat {
            
            // Get the graphics context.
            let currentContext = UIGraphicsGetCurrentContext()!
            
            // Push state
            currentContext.saveGState()
            
            // Put the text matrix into a known state. This ensures
            // that no old scaling factors are left in place.
            currentContext.textMatrix = CGAffineTransform.identity
            
            // print("y offset: \t\(drawingYOffset)")
            
            let textMaxWidth = pageBounds.width - 2*pageMargin
            let textMaxHeight = pageBounds.height - pageMargin - drawingYoffset
            
            // print("drawing y offset: \t\(drawingYOffset)")
            // print("text max height: \t\(textMaxHeight)")
            
            // Create a path object to enclose the text.
            let frameRect = CGRect(x: pageMargin, y: drawingYoffset, width: textMaxWidth, height: textMaxHeight)
            let framePath = UIBezierPath(rect: frameRect).cgPath
            
            // Get the frame that will do the rendering.
            // The currentRange variable specifies only the starting point. The framesetter
            // lays out as much text as will fit into the frame.
            let frameRef = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
            
            // Core Text draws from the bottom-left corner up, so flip
            // the current transform prior to drawing.
            currentContext.translateBy(x: 0, y: pageBounds.height + drawingYoffset - pageMargin)
            currentContext.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the frame.
            CTFrameDraw(frameRef, currentContext)
            
            // Pop state
            currentContext.restoreGState()
            
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
            if currentRange.location == CFAttributedStringGetLength(currentText) {
                done = true
                // print("exit")
            } else {
                // begin a new page to draw text that is remaining.
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                drawingYoffset = pageMargin
                // print("begin a new page to draw text that is remaining")
            }
            
            
        } while(!done)
        
        return lastDrawnFrame
    }
    
    /// - returns: drawing image rect
    fileprivate func drawImage(_ image: UIImage, alignment: ContentAlignment, currentYoffset: CGFloat) -> CGRect {
        
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
        switch alignment {
        case .left:
            renderingXoffset = pageMargin
        case .center:
            renderingXoffset = ( pageBounds.width - aspectWidth ) / 2.0
        case .right:
            let right = pageBounds.width - pageMargin
            renderingXoffset =  right - aspectWidth
        }
        
        let renderingRect = CGRect(x: renderingXoffset, y: currentYoffset, width: aspectWidth, height: aspectHeight)
        
        // render image to current pdf context
        image.draw(in: renderingRect)
        
        return renderingRect
    }
    
    fileprivate func drawLineSeparator(height: CGFloat, currentYoffset: CGFloat) -> CGRect {
        
        let drawRect = CGRect(x: pageMargin, y: currentYoffset, width: pageBounds.width - 2*pageMargin, height: height)
        let path = UIBezierPath(rect: drawRect).cgPath
        
        // Get the graphics context.
        let currentContext = UIGraphicsGetCurrentContext()!
        
        // Set color
        UIColor.black.setStroke()
        UIColor.black.setFill()
        
        // Draw path
        currentContext.addPath(path)
        currentContext.drawPath(using: .fillStroke)
        
        // print(drawRect)
        
        return drawRect
    }
    
    fileprivate func drawTable(rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>, currentYoffset: CGFloat) -> CGRect {
        
        let height = (CGFloat(rowCount)*rowHeight)
        
        let drawRect = CGRect(x: pageMargin, y: currentYoffset, width: pageBounds.width - 2*pageMargin, height: height)
        
        UIColor.black.setStroke()
        UIColor.black.setFill()
        
        for i in 0...rowCount {
            let newOrigin = drawRect.origin.y + rowHeight*CGFloat(i)
            
            let from = CGPoint(x: drawRect.origin.x, y: newOrigin)
            let to = CGPoint(x: drawRect.origin.x + CGFloat(columnCount)*columnWidth, y: newOrigin)
            
            drawLineFromPoint(from, to: to, lineWidth: tableLineWidth)
        }
        
        for i in 0...columnCount {
            let newOrigin = drawRect.origin.x + columnWidth*CGFloat(i)
            
            let from = CGPoint(x: newOrigin, y: drawRect.origin.y)
            let to = CGPoint(x: newOrigin, y: drawRect.origin.y + CGFloat(rowCount)*rowHeight)
            
            drawLineFromPoint(from, to: to, lineWidth: tableLineWidth)
        }
        
        for i in 0..<rowCount {
            for j in 0...columnCount-1 {
                let newOriginX = drawRect.origin.x + (CGFloat(j)*columnWidth)
                let newOriginY = drawRect.origin.y + ((CGFloat(i)*rowHeight))
                
                let frame = CGRect(x: newOriginX, y: newOriginY, width: columnWidth, height: rowHeight)
                drawTextInCell(frame, text: dataArray[i][j] as NSString, font: font)
            }
        }
        
        return drawRect
    }
    
    fileprivate func drawLineFromPoint(_ from: CGPoint, to: CGPoint, lineWidth: CGFloat) {
        let context = UIGraphicsGetCurrentContext()!
        context.setLineWidth(lineWidth)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let color = CGColor(colorSpace: colorspace, components: [0.2, 0.2, 0.2, 1.0])
        
        context.setStrokeColor(color!)
        context.move(to: CGPoint(x: from.x, y: from.y))
        context.addLine(to: CGPoint(x: to.x, y: to.y))
        
        context.strokePath()
    }
    
    fileprivate func drawTextInCell(_ rect: CGRect, text: NSString, font: UIFont) {
        let fieldColor = UIColor.black
        
        let paraStyle = NSMutableParagraphStyle()
        
        let skew = 0.0
        
        let attributes: [String: AnyObject] = [
            NSForegroundColorAttributeName: fieldColor,
            NSParagraphStyleAttributeName: paraStyle,
            NSObliquenessAttributeName: skew as AnyObject,
            NSFontAttributeName: font
        ]
        
        let size = text.size(attributes: attributes)
        
        let x = (rect.size.width - size.width)/2
        let y = (rect.size.height - size.height)/2
        
        
        text.draw(at: CGPoint(x: rect.origin.x + x, y: rect.origin.y + y), withAttributes: attributes)
    }
    
    
    open func generatePDFdata() -> Data {
        
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, pageBounds, nil)
        UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
        
        var currentYoffset = pageMargin
        var alignment = ContentAlignment.left
        var font = UIFont.systemFont( ofSize: UIFont.systemFontSize )
        
        for command in commands {
            
            switch command{
            case let .addText(text):
                let textFrame = drawText(text, font: font, alignment: alignment, currentYoffset: currentYoffset)
                currentYoffset = textFrame.origin.y + textFrame.height
                
            case let .addAttributedText(attributedText):
                let textFrame = drawAttributedText(attributedText, currentYoffset: currentYoffset)
                currentYoffset = textFrame.origin.y + textFrame.height
                
            case let .addImage(image):
                let imageFrame = drawImage(image, alignment: alignment, currentYoffset: currentYoffset)
                currentYoffset = imageFrame.origin.y + imageFrame.height
                
            case let .addLineSeparator(height: height):
                let drawRect = drawLineSeparator(height: height, currentYoffset: currentYoffset)
                currentYoffset = drawRect.origin.y + drawRect.height
                
            case let .addLineSpace(space):
                currentYoffset += space
                
            case let .addTable(rowCount, columnCount, rowHeight, columnWidth, tableLineWidth, font, dataArray):
                let tableFrame = drawTable(rowCount: rowCount, columnCount: columnCount, rowHeight: rowHeight, columnWidth: columnWidth, tableLineWidth: tableLineWidth, font: font, dataArray: dataArray, currentYoffset: currentYoffset)
                currentYoffset = tableFrame.origin.y + tableFrame.height
                
            case let .setContentAlignment(newAlignment):
                alignment = newAlignment
                
            case .beginNewPage:
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                currentYoffset = pageMargin
                
            case let .setFont(newFont):
                font = newFont
            }
            
        }
        
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
    
}
