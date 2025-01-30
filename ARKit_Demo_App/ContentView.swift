//
//  ContentView.swift
//  ARKit_Demo_App
//
//  Created by vignesh kumar c on 28/01/25.
//

import SwiftUI
import SceneKit
import UIKit
import ARKit

struct ContentView : View {
    @State private var selectedModel: String = "teapot copy"
    @State private var shouldReset: Bool = false
    @State private var showModelPicker: Bool = false
    var body: some View {
        ZStack {
            ARViewContainer(selectedModel: $selectedModel, shouldReset: $shouldReset)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button {
                        shouldReset = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title)
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
                
                Button {
                    showModelPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding()
                .sheet(isPresented: $showModelPicker) {
                    ModelPicker(selectedModel: $selectedModel)
                }
            }
        }
    }

}

extension UIColor {
    static let transperentBlue = UIColor(red: 0, green: 0, blue: 1, alpha: 0.2)
}

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    var arView: ARSCNView!
    var selectedModel: String = "teapot copy"
    var onResetScene: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARSCNView(frame: view.bounds)
        arView.delegate = self
        arView.session.delegate = self
        arView.automaticallyUpdatesLighting = true
        arView.scene = SCNScene()
        view.addSubview(arView)
        // Mark: Start ArSession
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startARSession()
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
        
        let apiURL = "art.scnassets/teapotcopy.scn"
        
        fetchModelURL(from: apiURL) { modelURL in
               if let modelURL = modelURL {
                   self.downloadSCNFile(from: modelURL) { localURL in
                       if let localURL = localURL {
                           DispatchQueue.main.async {
                               self.loadDownloadedModel(from: localURL)
                           }
                       } else {
                           print("Failed to download the model")
                       }
                   }
               } else {
                   print("Failed to fetch model URL")
               }
           }
    }
    
    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal] // Make sure horizontal plane detection is enabled
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
    }
    
    private func add3DObject(at hitResult: ARHitTestResult) {
        let modelName = selectedModel
           print("✅ Adding 3D object: \(modelName) at \(hitResult.worldTransform.columns.3)")
           
           guard let scene = SCNScene(named: "art.scnassets/\(modelName).scn") else {
               print("❌ Model not found: \(modelName)")
               return
           }
           
           let containerNode = SCNNode()
           containerNode.name = "container_\(modelName)"
           
           for child in scene.rootNode.childNodes {
               let childClone = child.clone()
               containerNode.addChildNode(childClone)
           }
           
           containerNode.position = SCNVector3(
               hitResult.worldTransform.columns.3.x,
               hitResult.worldTransform.columns.3.y,
               hitResult.worldTransform.columns.3.z
           )
           
           arView.scene.rootNode.addChildNode(containerNode)
           print("✅ 3D object added successfully!")
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let touchLocation = gesture.location(in: arView)
          print("🛑 Tap location: \(touchLocation)")

          let hitTestResults = arView.hitTest(touchLocation, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
          
//          if let hitResult = hitTestResults.first {
//              print("✅ Hit test succeeded, adding object...")
//              add3DObject(at: hitResult)
//          } else {
//              print("❌ No plane detected under tap. 🔄 Restarting AR session...")
//              startARSession() // Try resetting the session to re-detect planes
//          }
        if hitTestResults.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("❌ Still no plane detected. Restarting AR session...")
                self.startARSession()
            }
        } else {
            add3DObject(at: hitTestResults.first!)
        }
    }
   
    func resetScene() {
        arView.session.pause()
        arView.scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
        startARSession()
    }
    
    func render(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        print("✅ Plane detected at \(planeAnchor.center) with extent \(planeAnchor.extent)")
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        plane.materials.first?.diffuse.contents = UIColor.transperentBlue
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        node.addChildNode(planeNode)
    }
    
    func fetchModelURL(from apiURL: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: apiURL) else {
            print("Invalid API URL")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("API Request Failed:", error?.localizedDescription ?? "Unknown error")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let modelURL = json["modelURL"] as? String {
                    completion(modelURL)
                } else {
                    print("Invalid JSON format")
                    completion(nil)
                }
            } catch {
                print("JSON Parsing Error:", error.localizedDescription)
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    func downloadSCNFile(from urlString: String, completion: @escaping (URL?) -> Void) {
        guard let url = URL(string: urlString) else {
            print("Invalid model URL")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            guard let tempURL = tempURL, error == nil else {
                print("Download Failed:", error?.localizedDescription ?? "Unknown error")
                completion(nil)
                return
            }
            
            let fileName = url.lastPathComponent
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            
            do {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
                print("File saved to:", destinationURL)
                completion(destinationURL)
            } catch {
                print("File Move Error:", error.localizedDescription)
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    func loadDownloadedModel(from fileURL: URL) {
        do {
            let scene = try SCNScene(url: fileURL, options: nil)
            if let modelNode = scene.rootNode.childNodes.first {
                modelNode.scale = SCNVector3(0.002, 0.002, 0.002) // Adjust scale
                arView.scene.rootNode.addChildNode(modelNode)
            } else {
                print("Model node not found in SCN file")
            }
        } catch {
            print("Failed to load SCN file:", error.localizedDescription)
        }
    }
}

struct ARViewContainer: UIViewControllerRepresentable {
    @Binding var selectedModel: String
    @Binding var shouldReset: Bool
    
    func makeUIViewController(context: Context) -> ARViewController {
        let controller = ARViewController()
        controller.selectedModel = selectedModel
        controller.onResetScene = {
            controller.resetScene()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        uiViewController.selectedModel = selectedModel
        if shouldReset {
            uiViewController.resetScene()
            DispatchQueue.main.async {
                shouldReset = false
            }
        }
    }
}

struct ModelPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedModel: String
    
    let models = ["teapot", "chair", "lamp", "cup", "sticky_note", "painting"]
    var body: some View {
        NavigationStack {
            List(models, id: \.self) { model in
                
                Button {
                    selectedModel = model
                } label: {
                    HStack {
                        Text(model.replacingOccurrences(of: "_", with: " ").capitalized)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedModel == model {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
            }
            .navigationTitle("Select a model")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    ContentView()
}
