//
//  SimplePDFTests.swift
//  SimplePDFTests
//
//  Created by Nutchaphon Rewik on 17/01/2016.
//  Copyright © 2016 Nutchaphon Rewik. All rights reserved.
//

import XCTest
@testable import SimplePDF

class SimplePDFTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let a4PaperSize = CGSize(width: 595, height: 842)
        let pdf = SimplePDF(pageSize: a4PaperSize)
        
        // load test image
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "simple_pdf_logo", ofType: "png")!
        let image = UIImage(contentsOfFile: path)!
        
        pdf.setContentAlignment(.center)
        pdf.addImage(image)
        
        pdf.addLineSpace(30)

        pdf.setContentAlignment(.left)
        pdf.addText("Normal text follows by line separator")
        pdf.addLineSeparator()
        
        pdf.addLineSpace(20.0)
        
        pdf.setContentAlignment(.right)
        pdf.addText("Text after set content alignment to .Right")
        pdf.addLineSpace(20.0)
        
        pdf.addText("Cras quis eros orci.\nLorem ipsum dolor sit amet, consectetur adipiscing elit.\nDonec mollis vitae mi ut lobortis.\nUt ultrices mi vel neque venenatis, ut efficitur metus eleifend. Sed pellentesque lobortis est quis maximus. Maecenas ultricies risus et enim consectetur, id lobortis ante porta. Quisque at euismod enim. Vestibulum faucibus purus non justo fringilla, sit amet iaculis ex pellentesque. Vestibulum eget vulputate diam, sit amet ornare sem. Duis at eros non tortor malesuada accumsan.\nNunc vel libero ut sapien dictum iaculis a vel odio. Quisque purus turpis, tristique auctor ex non, consectetur scelerisque lorem. Mauris est justo, sollicitudin sit amet nisi a, mattis posuere orci. Sed elementum est at est tristique gravida. Aliquam iaculis, metus facilisis varius viverra, nunc libero ultricies arcu, in accumsan sem nibh vel purus.")
        
        pdf.addLineSpace(30)
        
        pdf.setContentAlignment(.center)

        pdf.addText("Center Text")
        pdf.addLineSpace(20.0)
        pdf.addText("Cras varius leo ac lectus malesuada, ut rhoncus nunc blandit.\n In venenatis diam et vehicula suscipit.\n Aliquam in ante at dolor sodales consectetur ut semper quam.\n Vivamus massa purus, congue sed leo sed, lobortis consectetur lacus. Nunc sed tortor nec augue mattis faucibus. Sed malesuada metus in sapien efficitur, ut aliquet nisl lobortis. Vestibulum faucibus purus non justo fringilla, sit amet iaculis ex pellentesque. Vestibulum eget vulputate diam, sit amet ornare sem. Aliquam erat volutpat. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Proin scelerisque posuere mi, non consequat mauris auctor a. Fusce lacinia auctor lectus a elementum.")
        
        
        pdf.addLineSpace(30.0)
        
        pdf.setContentAlignment(.left)
        let textString = "This is an example of long text. If the text doesn't fit in the current page. Simple pdf will draw a part of text, and automatically begin a new page to draw the remaining text. This process will be repeated until there's no text left to draw. "
        pdf.addText(textString)
        
        
        pdf.beginNewPage()
        pdf.addText("Begin new page")
        
        if let documentDirectories = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            
            let fileName = "example.pdf"
            let documentsFileName = documentDirectories + "/" + fileName
            
            let pdfData = pdf.generatePDFdata()
            do{
                try pdfData.write(to: URL(fileURLWithPath: documentsFileName), options: .atomic)
                print("\nThe generated pdf can be found at:")
                print("\n\t\(documentsFileName)\n")
            }catch{
                print(error)
            }
        }
        
    }
    
}
