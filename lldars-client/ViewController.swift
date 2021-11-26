import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    private let rootAnchor = AnchorEntity()
    
    var imageAnchorToEntity: [ARImageAnchor:AnchorEntity] = [:]
    // String->URLを持っておき，imageAnchorを検知したタイミングで名前と照合して読み取り
    var imageNameToEntityURLs: [String:[URL]] = [:]
    var imageConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        
        let images = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        configuration.detectionImages = images!
        configuration.maximumNumberOfTrackedImages = 1
        return configuration
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        LLDARSClient(configuration: &imageConfiguration, imageNameToEntityURLs: &imageNameToEntityURLs)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        arView.scene.addAnchor(rootAnchor)
        arView.session.run(imageConfiguration)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARImageAnchor }.forEach { anchor in
            // $0.name?なので，デフォを""にしてnilの場合にif letで殺せるようにする
            if let urls = imageNameToEntityURLs[anchor.name ?? ""] {
                let anchorEntity = AnchorEntity()
                
                urls.forEach { url in
                    if let entity = try? Entity.load(contentsOf: url) {
                        print("\(#function) EntityName: \(anchor.name!)")
                        print("\(#function) EntityURL: \(url)")
                        anchorEntity.addChild(entity)
                    }
                }
                arView.scene.addAnchor(anchorEntity)
                anchorEntity.transform.matrix = anchor.transform
                imageAnchorToEntity[anchor] = anchorEntity
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARImageAnchor }.forEach {
            let anchorEntity = imageAnchorToEntity[$0]
            anchorEntity?.transform.matrix = $0.transform
        }
    }
}
