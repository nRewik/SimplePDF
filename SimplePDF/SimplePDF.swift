//
//  SimplePDF.swift
//  SimplePDF
//
//  Created by Nutchaphon Rewik on 13/01/2016.
//  Copyright Â© 2016 Nutchaphon Rewik. All rights reserved.
//

import UIKit

private enum SimplePDFCommand {
    
    case addText(text:String, font:UIFont, textColor:UIColor)
    case addAttributedText( NSAttributedString )
    case addImage(UIImage)
    case addLineSpace(CGFloat)
    case addHorizontalSpace(CGFloat)
    case addLineSeparator(height: CGFloat)
    case addTable(rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat?, tableLineWidth: CGFloat, font: UIFont?, tableDefinition:TableDefinition?, dataArray: Array<Array<String>>)
    
    case setContentAlignment(ContentAlignment)
    case beginNewPage
    
    case beginHorizontalArrangement
    case endHorizontalArrangement
    
}

public enum ContentAlignment {
    case left, center, right
}

public struct TableDefinition {
    let alignments: [ContentAlignment]
    let columnWidths: [CGFloat]
    let fonts:[UIFont]
    let textColors:[UIColor]
    
    public init(alignments: [ContentAlignment],
                columnWidths: [CGFloat],
                fonts:[UIFont],
                textColors:[UIColor]) {
        self.alignments = alignments
        self.columnWidths = columnWidths
        self.fonts = fonts
        self.textColors = textColors
    }
}

open class SimplePDF {
    
    /* States */
    fileprivate var commands: [SimplePDFCommand] = []
    
    /* Initialization */
    fileprivate let pageBounds: CGRect
    fileprivate let pageMarginLeft: CGFloat
    fileprivate let pageMarginTop: CGFloat
    fileprivate let pageMarginBottom: CGFloat
    fileprivate let pageMarginRight: CGFloat
    
    public init(pageSize: CGSize, pageMargin: CGFloat = 20.0) {
        pageBounds = CGRect(origin: CGPoint.zero, size: pageSize)
        self.pageMarginLeft = pageMargin
        self.pageMarginTop = pageMargin
        self.pageMarginRight = pageMargin
        self.pageMarginBottom = pageMargin
    }
    
    public init(pageSize: CGSize, pageMarginLeft: CGFloat, pageMarginTop: CGFloat, pageMarginBottom: CGFloat, pageMarginRight: CGFloat) {
        pageBounds = CGRect(origin: CGPoint.zero, size: pageSize)
        self.pageMarginBottom = pageMarginBottom
        self.pageMarginRight = pageMarginRight
        self.pageMarginTop = pageMarginTop
        self.pageMarginLeft = pageMarginLeft
    }
    
    
    /// Text will be drawn from the current font and alignment settings.
    ///
    /// If text is too long and doesn't fit in the current page.
    /// SimplePDF will begin a new page and draw remaining text.
    ///
    /// This process will be repeated untill there's no text left to draw.
    open func addText(_ text: String, font:UIFont = UIFont.systemFont(ofSize: UIFont.systemFontSize), textColor:UIColor = UIColor.black) {
        commands += [ .addText(text: text, font: font, textColor: textColor) ]
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
    
    open func addVerticalSpace(_ space:CGFloat) {
        commands += [ .addLineSpace(space) ]
    }
    
    open func addHorizontalSpace(_ space: CGFloat) {
        commands += [ .addHorizontalSpace(space) ]
    }
    
    open func addLineSeparator(height: CGFloat = 1.0) {
        commands += [ .addLineSeparator(height: height) ]
    }
    
    open func addTable(_ rowCount: Int, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat, tableLineWidth: CGFloat, font: UIFont, dataArray: Array<Array<String>>) {
        commands += [ .addTable(rowCount: rowCount, columnCount: columnCount, rowHeight: rowHeight, columnWidth: columnWidth, tableLineWidth: tableLineWidth, font: font, tableDefinition: nil, dataArray: dataArray) ]
    }
    
    open func addTable(_ rowCount: Int, columnCount: Int, rowHeight: CGFloat, tableLineWidth: CGFloat, tableDefinition: TableDefinition, dataArray: Array<Array<String>>) {
        commands += [ .addTable(rowCount: rowCount, columnCount: columnCount, rowHeight: rowHeight, columnWidth: nil, tableLineWidth: tableLineWidth, font: nil, tableDefinition: tableDefinition, dataArray: dataArray) ]
    }
    
    open func setContentAlignment(_ alignment: ContentAlignment) {
        commands += [ .setContentAlignment(alignment) ]
    }
    
    open func beginNewPage() {
        commands += [ .beginNewPage ]
    }
    
    open func beginHorizontalArrangement() {
        commands += [ .beginHorizontalArrangement ]
    }
    
    open func endHorizontalArrangement() {
        commands += [ .endHorizontalArrangement ]
    }
    
    /// - returns: drawing text rect
    fileprivate func drawText(_ text: String, font: UIFont, textColor: UIColor, alignment: ContentAlignment, currentOffset: CGPoint) -> CGRect {
        
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
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        return drawAttributedText(attributedText, currentOffset: currentOffset)
    }
    
    fileprivate func drawAttributedText( _ attributedText: NSAttributedString, currentOffset: CGPoint) -> CGRect {
        
        var drawingYoffset = currentOffset.y
        
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
            
            let textMaxWidth = pageBounds.width - pageMarginLeft - pageMarginRight - currentOffset.x
            let textMaxHeight = pageBounds.height - pageMarginBottom - drawingYoffset
            
            // print("drawing y offset: \t\(drawingYOffset)")
            // print("text max height: \t\(textMaxHeight)")
            
            // Create a path object to enclose the text.
            let frameRect = CGRect(x: currentOffset.x, y: drawingYoffset, width: textMaxWidth, height: textMaxHeight)
            let framePath = UIBezierPath(rect: frameRect).cgPath
            
            // Get the frame that will do the rendering.
            // The currentRange variable specifies only the starting point. The framesetter
            // lays out as much text as will fit into the frame.
            let frameRef = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)
            
            // Core Text draws from the bottom-left corner up, so flip
            // the current transform prior to drawing.
            currentContext.translateBy(x: 0, y: pageBounds.height + drawingYoffset - pageMarginBottom)
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
            lastDrawnFrame = CGRect(x: currentOffset.x, y: drawingYoffset, width: drawnSize.width, height: drawnSize.height)
            
            // print(suggestionSize)
            
            // If we're at the end of the text, exit the loop.
            // print("\(currentRange.location) \(CFAttributedStringGetLength(currentText))")
            if currentRange.location == CFAttributedStringGetLength(currentText) {
                done = true
                // print("exit")
            } else {
                // begin a new page to draw text that is remaining.
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                drawingYoffset = pageMarginTop
                // print("begin a new page to draw text that is remaining")
            }
            
            
        } while(!done)
        
        return lastDrawnFrame
    }
    
    /// - returns: drawing image rect
    fileprivate func drawImage(_ image: UIImage, alignment: ContentAlignment, currentOffset: CGPoint) -> CGRect {
        
        /* calculate the aspect size of image */
        
        let maxWidth = min( image.size.width, pageBounds.width )
        let maxHeight = min( image.size.height, pageBounds.height - currentOffset.y )
        
        let wFactor = image.size.width / maxWidth
        let hFactor = image.size.height / maxHeight
        
        let factor = max(wFactor, hFactor)
        
        let aspectWidth = image.size.width / factor
        let aspectHeight = image.size.height / factor
        
        /* calculate x offset for rendering */
        let renderingXoffset: CGFloat
        switch alignment {
        case .left:
            renderingXoffset = currentOffset.x
        case .center:
            renderingXoffset = ( pageBounds.width - currentOffset.x - aspectWidth ) / 2.0
        case .right:
            let right = pageBounds.width - pageMarginRight
            renderingXoffset =  right - aspectWidth
        }
        
        let renderingRect = CGRect(x: renderingXoffset, y: currentOffset.y, width: aspectWidth, height: aspectHeight)
        
        // render image to current pdf context
        image.draw(in: renderingRect)
        
        return renderingRect
    }
    
    fileprivate func drawLineSeparator(height: CGFloat, currentOffset: CGPoint) -> CGRect {
        
        let drawRect = CGRect(x: currentOffset.x, y: currentOffset.y, width: pageBounds.width - pageMarginLeft - pageMarginRight, height: height)
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
    
    fileprivate func drawTable(rowCount: Int, alignment: ContentAlignment, columnCount: Int, rowHeight: CGFloat, columnWidth: CGFloat?, tableLineWidth: CGFloat, font: UIFont?, tableDefinition:TableDefinition?, dataArray: Array<Array<String>>, currentOffset: CGPoint) -> CGRect {
        
        let height = (CGFloat(rowCount)*rowHeight)
        
        let drawRect = CGRect(x: currentOffset.x, y: currentOffset.y, width: pageBounds.width - pageMarginLeft - pageMarginRight, height: height)
        
        UIColor.black.setStroke()
        UIColor.black.setFill()
        
        let tableWidth = { () -> CGFloat in
            if let cws = tableDefinition?.columnWidths {
                return cws.reduce(0, { (result, current) -> CGFloat in
                    return result + current
                })
            } else if let cw = columnWidth {
                return CGFloat(columnCount) * cw
            }
            
            return 0 // default which should never be use, because either columnWidth, or columnsWidths is set
        }()
        
        for i in 0...rowCount {
            let newOrigin = drawRect.origin.y + rowHeight*CGFloat(i)
            
            
            
            let from = CGPoint(x: drawRect.origin.x, y: newOrigin)
            let to = CGPoint(x: drawRect.origin.x + tableWidth, y: newOrigin)
            
            drawLineFromPoint(from, to: to, lineWidth: tableLineWidth)
        }
        
        for i in 0...columnCount {
            let currentOffset = { () -> CGFloat in
                if let cws = tableDefinition?.columnWidths {
                    var offset:CGFloat = 0
                    for x in 0..<i {
                        offset += cws[x]
                    }
                    return offset
                } else if let cw = columnWidth {
                    return cw * CGFloat(i)
                }
                
                return 0 // default which should never be use, because either columnWidth, or columnsWidths is set
            }()
            
            let newOrigin = drawRect.origin.x + currentOffset
            
            let from = CGPoint(x: newOrigin, y: drawRect.origin.y)
            let to = CGPoint(x: newOrigin, y: drawRect.origin.y + CGFloat(rowCount)*rowHeight)
            
            drawLineFromPoint(from, to: to, lineWidth: tableLineWidth)
        }
        
        for i in 0..<rowCount {
            for j in 0...columnCount-1 {
                let currentOffset = { () -> CGFloat in
                    if let cws = tableDefinition?.columnWidths {
                        var offset:CGFloat = 0
                        for x in 0..<j {
                            offset += cws[x]
                        }
                        return offset
                    } else if let cw = columnWidth {
                        return cw * CGFloat(j)
                    }
                    
                    return 0 // default which should never be use, because either columnWidth, or columnsWidths is set
                }()
                
                let newOriginX = drawRect.origin.x + currentOffset
                let newOriginY = drawRect.origin.y + ((CGFloat(i)*rowHeight))
                
                let currentFont = { () -> UIFont in
                    if let f = tableDefinition?.fonts {
                        if (f.count > j){
                            return f[j]
                        }
                    } else if let f = font {
                        return f
                    }
                    
                    return UIFont.systemFont(ofSize: UIFont.systemFontSize)
                }()
                
                let currentTextColor = { () -> UIColor in
                    if let t = tableDefinition?.textColors {
                        if t.count > j {
                            return t[j]
                        }
                    }
                    
                    return UIColor.black
                }()
                
                let currentColumnWidth = { () -> CGFloat in
                    if let cw = tableDefinition?.columnWidths {
                        if cw.count > j {
                            return cw[j]
                        }
                    } else if let cw = columnWidth {
                        return cw
                    }
                    
                    return 100 // default which should never be use, because either columnWidth, or columnsWidths is set
                }()
                
                let frame = CGRect(x: newOriginX, y: newOriginY, width: currentColumnWidth, height: rowHeight)
                drawTextInCell(frame, text: dataArray[i][j] as NSString, alignment: alignment, font: currentFont, textColor: currentTextColor)
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
    
    fileprivate func drawTextInCell(_ rect: CGRect, text: NSString, alignment: ContentAlignment, font: UIFont, textColor:UIColor) {
        let paraStyle = NSMutableParagraphStyle()
        
        let skew = 0.0
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .paragraphStyle: paraStyle,
            .obliqueness: skew,
            .font: font
        ]
        
        let size = text.size(withAttributes: attributes)
        
        let x:CGFloat = { () -> CGFloat in
            switch alignment {
            case .left:
                return 0
            case .center:
                return (rect.size.width - size.width)/2
            case .right:
                return rect.size.width - size.width
            }
        }()
        let y = (rect.size.height - size.height)/2
        
        text.draw(at: CGPoint(x: rect.origin.x + x, y: rect.origin.y + y), withAttributes: attributes)
    }
    
    enum ArrangementDirection {
        case horizontal
        case vertical
    }
    
    open func generatePDFdata() -> Data {
        
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, pageBounds, nil)
        UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
        
        var currentOffset = CGPoint(x: pageMarginLeft, y: pageMarginTop)
        var alignment = ContentAlignment.left
        var arrangementDirection = ArrangementDirection.vertical
        var lastYOffset = currentOffset.y
        
        for command in commands {
            
            switch command{
            case let .addText(text, font, textColor):
                let textFrame = drawText(text, font: font, textColor: textColor, alignment: alignment, currentOffset: currentOffset)
                lastYOffset = textFrame.origin.y + textFrame.height
                switch arrangementDirection {
                case .horizontal:
                    currentOffset = CGPoint(x: textFrame.origin.x + textFrame.width, y: currentOffset.y)
                case .vertical:
                    currentOffset = CGPoint(x: currentOffset.x, y: lastYOffset)
                }
                
            case let .addAttributedText(attributedText):
                let textFrame = drawAttributedText(attributedText, currentOffset: currentOffset)
                lastYOffset = textFrame.origin.y + textFrame.height
                switch arrangementDirection {
                case .horizontal:
                    currentOffset = CGPoint(x: textFrame.origin.x + textFrame.width, y: currentOffset.y)
                case .vertical:
                    currentOffset = CGPoint(x: currentOffset.x, y: lastYOffset)
                }
                
            case let .addImage(image):
                let imageFrame = drawImage(image, alignment: alignment, currentOffset: currentOffset)
                lastYOffset = imageFrame.origin.y + imageFrame.height
                switch arrangementDirection {
                case .horizontal:
                    currentOffset = CGPoint(x: imageFrame.origin.x + imageFrame.width, y: currentOffset.y)
                case .vertical:
                    currentOffset = CGPoint(x: currentOffset.x, y: lastYOffset)
                }
                
            case let .addLineSeparator(height: height):
                let drawRect = drawLineSeparator(height: height, currentOffset: currentOffset)
                lastYOffset = drawRect.origin.y + drawRect.height
                switch arrangementDirection {
                case .horizontal:
                    currentOffset = CGPoint(x: drawRect.origin.x + drawRect.width, y: currentOffset.y)
                case .vertical:
                    currentOffset = CGPoint(x: currentOffset.x, y: lastYOffset)
                }
                
            case let .addLineSpace(space):
                lastYOffset = currentOffset.y + space
                currentOffset = CGPoint(x: currentOffset.x, y: lastYOffset)
                
            case let .addHorizontalSpace(space):
                lastYOffset = currentOffset.y
                currentOffset = CGPoint(x: currentOffset.x + space, y: currentOffset.y)
                
            case let .addTable(rowCount, columnCount, rowHeight, columnWidth, tableLineWidth, font, tableDefinition, dataArray):
                let tableFrame = drawTable(rowCount: rowCount, alignment: alignment, columnCount: columnCount, rowHeight: rowHeight, columnWidth: columnWidth, tableLineWidth: tableLineWidth, font: font, tableDefinition: tableDefinition, dataArray: dataArray, currentOffset: currentOffset)
                lastYOffset = tableFrame.origin.y + tableFrame.height
                switch arrangementDirection {
                case .horizontal:
                    currentOffset = CGPoint(x: tableFrame.origin.x + tableFrame.width, y: currentOffset.y)
                case .vertical:
                    currentOffset = CGPoint(x: currentOffset.x, y: lastYOffset)
                }
                
            case let .setContentAlignment(newAlignment):
                alignment = newAlignment
                
            case .beginNewPage:
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                currentOffset = CGPoint(x: pageMarginLeft, y: pageMarginTop)
                lastYOffset = currentOffset.y
                
            case .beginHorizontalArrangement:
                arrangementDirection = .horizontal
                
            case .endHorizontalArrangement:
                arrangementDirection = .vertical
                currentOffset = CGPoint(x: pageMarginLeft, y: lastYOffset)
            }
        }
        
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
    
}
