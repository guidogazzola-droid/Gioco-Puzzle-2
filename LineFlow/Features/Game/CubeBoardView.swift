import SwiftUI
import RealityKit
import UIKit
import PuzzleKit

/// The interactive cubical instrument shown during play.
struct CubeBoardView: View {
    let engine: CubePuzzleEngine
    let theme: GameTheme
    var colorBlindAssist = false
    var isInteractive = true
    var onBegin: (CubeCell) -> Bool = { _ in false }
    var onExtend: (CubeCell) -> Bool = { _ in false }
    var onEnd: () -> Void = {}
    var onRotate: (CubeCell) -> Bool = { _ in false }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Ink.stroke.opacity(0.7), lineWidth: 1)
                )

            CubeBoardRealityView(
                engine: engine,
                theme: theme,
                colorBlindAssist: colorBlindAssist,
                isInteractive: isInteractive,
                onBegin: onBegin,
                onExtend: onExtend,
                onEnd: onEnd,
                onRotate: onRotate
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack {
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "rotate.3d")
                    Text("game.cube.hint")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 10)
            }
            .allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text("game.cube.hint"))
    }

    private var accessibilityLabel: String {
        String(
            format: NSLocalizedString("a11y.cube", comment: "Cubical board summary"),
            engine.blueprint.activeFaces.count,
            engine.connectedColors,
            engine.colorCount
        )
    }
}

/// RealityKit bridge. The static cube is retained while trails and rotors are
/// updated, so a finger drag does not rebuild collision meshes or the camera.
private struct CubeBoardRealityView: UIViewRepresentable {
    let engine: CubePuzzleEngine
    let theme: GameTheme
    let colorBlindAssist: Bool
    let isInteractive: Bool
    let onBegin: (CubeCell) -> Bool
    let onExtend: (CubeCell) -> Bool
    let onEnd: () -> Void
    let onRotate: (CubeCell) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        view.isOpaque = false
        view.backgroundColor = .clear
        view.environment.background = .color(.clear)
        context.coordinator.install(in: view)
        context.coordinator.rebuildStaticScene(resetRotation: true)
        context.coordinator.updateDynamicScene()
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshIfNeeded()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CubeBoardRealityView

        private weak var view: ARView?
        private let worldAnchor = AnchorEntity(world: .zero)
        private let cubeRoot = Entity()
        private let dynamicRoot = Entity()
        private var tileEntities: [CubeCell: ModelEntity] = [:]
        private var renderedBlueprintID: String?
        private var renderedTheme: GameTheme?

        private enum PanMode { case drawing, rotating }
        private var panMode: PanMode?
        private var lastCell: CubeCell?
        private var rotationAtPanStart = simd_quatf(angle: 0, axis: [0, 1, 0])

        private let cubeHalfExtent: Float = 1.18
        private let tileDepth: Float = 0.045

        init(parent: CubeBoardRealityView) {
            self.parent = parent
            super.init()
        }

        func install(in view: ARView) {
            self.view = view
            view.scene.anchors.append(worldAnchor)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 40
            camera.position = [0, 0, 5.45]
            worldAnchor.addChild(camera)

            let keyLight = DirectionalLight()
            keyLight.light.intensity = 18_000
            keyLight.look(at: .zero, from: [3.5, 4.5, 5], relativeTo: nil)
            worldAnchor.addChild(keyLight)

            let fillLight = PointLight()
            fillLight.light.intensity = 9_000
            fillLight.light.attenuationRadius = 9
            fillLight.position = [-3, -1.5, 4]
            worldAnchor.addChild(fillLight)

            worldAnchor.addChild(cubeRoot)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            view.addGestureRecognizer(pan)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap)
        }

        func refreshIfNeeded() {
            let blueprintChanged = renderedBlueprintID != parent.engine.blueprint.id
            let themeChanged = renderedTheme != parent.theme
            if blueprintChanged || themeChanged {
                rebuildStaticScene(resetRotation: blueprintChanged)
            }
            updateDynamicScene()
        }

        func rebuildStaticScene(resetRotation: Bool) {
            for child in Array(cubeRoot.children) { child.removeFromParent() }
            tileEntities.removeAll(keepingCapacity: true)
            renderedBlueprintID = parent.engine.blueprint.id
            renderedTheme = parent.theme

            if resetRotation {
                let yaw = simd_quatf(angle: -.pi / 5.5, axis: [0, 1, 0])
                let pitch = simd_quatf(angle: -.pi / 8, axis: [1, 0, 0])
                cubeRoot.orientation = yaw * pitch
            }

            let core = ModelEntity(
                mesh: .generateBox(size: cubeHalfExtent * 1.94),
                materials: [material(.init(white: 0.035, alpha: 1), roughness: 0.34, metallic: true)]
            )
            cubeRoot.addChild(core)

            let side = parent.engine.blueprint.side
            let cellSize = cubeHalfExtent * 2 / Float(side)
            for face in CubeFace.allCases {
                for y in 0..<side {
                    for x in 0..<side {
                        let cell = CubeCell(face: face, x: x, y: y)
                        let active = parent.engine.blueprint.activeFaces.contains(face)
                        let blocked = parent.engine.blueprint.isBlocked(cell)
                        let tint: UIColor
                        if blocked {
                            tint = UIColor(white: 0.035, alpha: 1)
                        } else if active {
                            tint = UIColor(red: 0.075, green: 0.105, blue: 0.16, alpha: 1)
                        } else {
                            tint = UIColor(white: 0.055, alpha: 1)
                        }
                        let tile = ModelEntity(
                            mesh: .generateBox(size: [
                                cellSize * 0.91,
                                cellSize * 0.91,
                                tileDepth
                            ]),
                            materials: [material(tint, roughness: active ? 0.42 : 0.72, metallic: active)]
                        )
                        tile.name = Self.entityName(for: cell)
                        tile.position = surfacePosition(cell, lift: tileDepth * 0.30)
                        tile.orientation = faceOrientation(face)
                        if active {
                            tile.generateCollisionShapes(recursive: false)
                        }
                        cubeRoot.addChild(tile)
                        tileEntities[cell] = tile

                        if blocked { addWallMark(to: tile, cellSize: cellSize) }
                    }
                }
            }

            addEndpoints(cellSize: cellSize)
            cubeRoot.addChild(dynamicRoot)
        }

        func updateDynamicScene() {
            for child in Array(dynamicRoot.children) { child.removeFromParent() }
            let side = parent.engine.blueprint.side
            let cellSize = cubeHalfExtent * 2 / Float(side)

            for (color, path) in parent.engine.paths.enumerated() where path.count > 1 {
                let tint = UIColor(parent.theme.color(for: color))
                for index in 1..<path.count {
                    addTrailSegment(
                        from: path[index - 1],
                        to: path[index],
                        color: tint,
                        cellSize: cellSize
                    )
                }
                if !parent.engine.isConnected(color: color), let head = path.last {
                    let cap = ModelEntity(
                        mesh: .generateSphere(radius: cellSize * 0.145),
                        materials: [material(tint, roughness: 0.28, metallic: true)]
                    )
                    cap.position = surfacePosition(head, lift: 0.105)
                    dynamicRoot.addChild(cap)
                }
            }

            for rotor in parent.engine.blueprint.fluxRotors {
                guard let orientation = parent.engine.rotorOrientation(at: rotor.cell) else { continue }
                addRotor(
                    rotor,
                    orientation: orientation,
                    aligned: parent.engine.isRotorAligned(at: rotor.cell),
                    cellSize: cellSize
                )
            }
        }

        // MARK: - Static pieces

        private func addEndpoints(cellSize: Float) {
            for (color, endpoints) in parent.engine.blueprint.endpoints.enumerated() {
                for (cell, polarity) in [
                    (endpoints.start, MagneticPolarity.north),
                    (endpoints.end, MagneticPolarity.south)
                ] {
                    let holder = Entity()
                    holder.position = surfacePosition(cell, lift: 0.075)
                    holder.orientation = faceOrientation(cell.face)

                    let circuitColor = UIColor(parent.theme.color(for: color))
                    let rim = ModelEntity(
                        mesh: .generateCylinder(height: 0.045, radius: cellSize * 0.29),
                        materials: [material(circuitColor, roughness: 0.24, metallic: true)]
                    )
                    rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    holder.addChild(rim)

                    let poleColor = polarity == .north
                        ? UIColor(red: 1, green: 0.25, blue: 0.34, alpha: 1)
                        : UIColor(red: 0.18, green: 0.75, blue: 1, alpha: 1)
                    let core = ModelEntity(
                        mesh: .generateCylinder(height: 0.055, radius: cellSize * 0.205),
                        materials: [material(poleColor, roughness: 0.34, metallic: false)]
                    )
                    core.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    core.position.z = 0.024
                    holder.addChild(core)
                    addLetter(polarity, to: holder, cellSize: cellSize, z: 0.058)
                    cubeRoot.addChild(holder)
                }
            }
        }

        private func addLetter(
            _ polarity: MagneticPolarity,
            to holder: Entity,
            cellSize: Float,
            z: Float
        ) {
            let ink = material(UIColor(white: 0.025, alpha: 0.92), roughness: 0.8, metallic: false)
            let stroke = cellSize * 0.035
            let height = cellSize * 0.25

            func bar(size: SIMD3<Float>, position: SIMD3<Float>, angle: Float = 0) {
                let entity = ModelEntity(mesh: .generateBox(size: size), materials: [ink])
                entity.position = position
                entity.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
                holder.addChild(entity)
            }

            if polarity == .north {
                bar(size: [stroke, height, 0.014], position: [-height * 0.27, 0, z])
                bar(size: [stroke, height, 0.014], position: [height * 0.27, 0, z])
                bar(
                    size: [stroke, height * 1.08, 0.014],
                    position: [0, 0, z],
                    angle: -.pi / 6
                )
            } else {
                let wide = height * 0.55
                bar(size: [wide, stroke, 0.014], position: [0, height * 0.40, z])
                bar(size: [wide, stroke, 0.014], position: [0, 0, z])
                bar(size: [wide, stroke, 0.014], position: [0, -height * 0.40, z])
                bar(size: [stroke, height * 0.42, 0.014], position: [-wide * 0.46, height * 0.20, z])
                bar(size: [stroke, height * 0.42, 0.014], position: [wide * 0.46, -height * 0.20, z])
            }
        }

        private func addWallMark(to tile: ModelEntity, cellSize: Float) {
            let wallMaterial = material(
                UIColor(white: 0.30, alpha: 0.55), roughness: 0.8, metallic: false
            )
            for angle in [Float(-.pi / 4), Float(.pi / 4)] {
                let bar = ModelEntity(
                    mesh: .generateBox(size: [cellSize * 0.55, cellSize * 0.055, 0.018]),
                    materials: [wallMaterial]
                )
                bar.position.z = tileDepth * 0.65
                bar.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
                tile.addChild(bar)
            }
        }

        // MARK: - Dynamic pieces

        private func addTrailSegment(
            from first: CubeCell,
            to second: CubeCell,
            color: UIColor,
            cellSize: Float
        ) {
            let lift: Float = 0.095
            let start = surfacePosition(first, lift: lift)
            let end = surfacePosition(second, lift: lift)
            let radius = cellSize * parent.theme.trail.thickness * 0.25

            if first.face == second.face {
                addCylinder(from: start, to: end, radius: radius, color: color)
            } else {
                let direction = CubeTopology.direction(
                    from: first, to: second, side: parent.engine.blueprint.side
                )!
                let face = first.face
                let movement: SIMD3<Float>
                switch direction {
                case .north: movement = -vector(face.downAxis)
                case .east: movement = vector(face.rightAxis)
                case .south: movement = vector(face.downAxis)
                case .west: movement = -vector(face.rightAxis)
                }
                let edgeBase = surfacePosition(first, lift: 0) + movement * (cellSize * 0.5)
                let bevelNormal = simd_normalize(vector(first.face.normal) + vector(second.face.normal))
                let edge = edgeBase + bevelNormal * lift
                addCylinder(from: start, to: edge, radius: radius, color: color)
                addCylinder(from: edge, to: end, radius: radius, color: color)
                let joint = ModelEntity(
                    mesh: .generateSphere(radius: radius * 1.02),
                    materials: [material(color, roughness: 0.24, metallic: true)]
                )
                joint.position = edge
                dynamicRoot.addChild(joint)
            }
        }

        private func addCylinder(
            from start: SIMD3<Float>,
            to end: SIMD3<Float>,
            radius: Float,
            color: UIColor
        ) {
            let delta = end - start
            let length = simd_length(delta)
            guard length > 0.0001 else { return }
            if parent.theme.trail.glowRadius > 0 {
                let glowColor = color.withAlphaComponent(0.18)
                let glow = ModelEntity(
                    mesh: .generateCylinder(
                        height: length,
                        radius: radius + parent.theme.trail.glowRadius * radius * 0.9
                    ),
                    materials: [material(glowColor, roughness: 0.9, metallic: false)]
                )
                placeCylinder(glow, from: start, to: end)
                dynamicRoot.addChild(glow)
            }
            let segment = ModelEntity(
                mesh: .generateCylinder(height: length, radius: radius),
                materials: [material(color, roughness: 0.20, metallic: true)]
            )
            placeCylinder(segment, from: start, to: end)
            dynamicRoot.addChild(segment)
        }

        private func placeCylinder(
            _ entity: ModelEntity,
            from start: SIMD3<Float>,
            to end: SIMD3<Float>
        ) {
            let direction = simd_normalize(end - start)
            entity.position = (start + end) / 2
            entity.orientation = simd_quatf(from: [0, 1, 0], to: direction)
        }

        private func addRotor(
            _ rotor: CubeFluxRotor,
            orientation: FluxOrientation,
            aligned: Bool,
            cellSize: Float
        ) {
            let holder = Entity()
            holder.position = surfacePosition(rotor.cell, lift: 0.09)
            holder.orientation = faceOrientation(rotor.cell.face)
            let tint = UIColor(parent.theme.color(for: rotor.color))

            let disc = ModelEntity(
                mesh: .generateCylinder(height: 0.045, radius: cellSize * 0.31),
                materials: [material(
                    UIColor(white: aligned ? 0.18 : 0.045, alpha: 1),
                    roughness: 0.32,
                    metallic: true
                )]
            )
            disc.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            holder.addChild(disc)

            let length = cellSize * 0.28
            let thickness = cellSize * 0.09
            for port in orientation.ports {
                let vertical = port == .north || port == .south
                let bar = ModelEntity(
                    mesh: .generateBox(size: vertical
                        ? [thickness, length, 0.035]
                        : [length, thickness, 0.035]
                    ),
                    materials: [material(tint, roughness: 0.24, metallic: true)]
                )
                let offset = length * 0.48
                switch port {
                case .north: bar.position = [0, offset, 0.035]
                case .east: bar.position = [offset, 0, 0.035]
                case .south: bar.position = [0, -offset, 0.035]
                case .west: bar.position = [-offset, 0, 0.035]
                }
                holder.addChild(bar)
            }
            let hub = ModelEntity(
                mesh: .generateSphere(radius: cellSize * 0.075),
                materials: [material(.white, roughness: 0.2, metallic: true)]
            )
            hub.position.z = 0.055
            holder.addChild(hub)
            dynamicRoot.addChild(holder)
        }

        // MARK: - Gesture routing

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.isInteractive, let view else { return }
            let point = gesture.location(in: view)
            switch gesture.state {
            case .began:
                if let cell = hitCell(at: point), parent.onBegin(cell) {
                    panMode = .drawing
                    lastCell = cell
                } else {
                    panMode = .rotating
                    rotationAtPanStart = cubeRoot.orientation
                }
            case .changed:
                switch panMode {
                case .drawing:
                    guard let previous = lastCell,
                          let target = hitCell(at: point), target != previous
                    else { return }
                    var reached = previous
                    for step in route(from: previous, to: target) {
                        guard parent.onExtend(step) else { break }
                        reached = step
                    }
                    lastCell = reached
                case .rotating:
                    let translation = gesture.translation(in: view)
                    let yaw = simd_quatf(
                        angle: Float(translation.x) * 0.008,
                        axis: [0, 1, 0]
                    )
                    let pitch = simd_quatf(
                        angle: Float(translation.y) * 0.008,
                        axis: [1, 0, 0]
                    )
                    cubeRoot.orientation = yaw * pitch * rotationAtPanStart
                case nil:
                    break
                }
            case .ended, .cancelled, .failed:
                if panMode == .drawing { parent.onEnd() }
                panMode = nil
                lastCell = nil
            default:
                break
            }
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isInteractive, let view,
                  let cell = hitCell(at: gesture.location(in: view))
            else { return }
            _ = parent.onRotate(cell)
        }

        private func hitCell(at point: CGPoint) -> CubeCell? {
            guard let hit = view?.hitTest(point).first else { return nil }
            var entity: Entity? = hit.entity
            while let current = entity {
                if let cell = Self.cell(from: current.name) { return cell }
                entity = current.parent
            }
            return nil
        }

        private func route(from start: CubeCell, to end: CubeCell) -> [CubeCell] {
            if CubeTopology.areAdjacent(start, end, side: parent.engine.blueprint.side) {
                return [end]
            }
            var queue = [start]
            var cursor = 0
            var previous: [CubeCell: CubeCell] = [:]
            var seen: Set<CubeCell> = [start]
            let blueprint = parent.engine.blueprint

            while cursor < queue.count {
                let cell = queue[cursor]
                cursor += 1
                for neighbour in cell.neighbours(side: blueprint.side)
                where blueprint.isPlayable(neighbour) && seen.insert(neighbour).inserted {
                    previous[neighbour] = cell
                    if neighbour == end {
                        var result = [end]
                        var step = end
                        while let parent = previous[step], parent != start {
                            result.append(parent)
                            step = parent
                        }
                        return result.reversed()
                    }
                    queue.append(neighbour)
                }
            }
            return []
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        // MARK: - Geometry helpers

        private func surfacePosition(_ cell: CubeCell, lift: Float) -> SIMD3<Float> {
            let side = Float(parent.engine.blueprint.side)
            let cellSize = cubeHalfExtent * 2 / side
            let localX = (Float(cell.x) + 0.5 - side / 2) * cellSize
            let localY = (side / 2 - Float(cell.y) - 0.5) * cellSize
            return vector(cell.face.normal) * (cubeHalfExtent + lift)
                + vector(cell.face.rightAxis) * localX
                - vector(cell.face.downAxis) * localY
        }

        private func faceOrientation(_ face: CubeFace) -> simd_quatf {
            let matrix = simd_float3x3(columns: (
                vector(face.rightAxis),
                -vector(face.downAxis),
                vector(face.normal)
            ))
            return simd_quatf(matrix)
        }

        private func vector(_ axis: CubeAxis) -> SIMD3<Float> {
            [Float(axis.x), Float(axis.y), Float(axis.z)]
        }

        private func material(
            _ color: UIColor,
            roughness: Float,
            metallic: Bool
        ) -> SimpleMaterial {
            SimpleMaterial(color: color, roughness: roughness, isMetallic: metallic)
        }

        private static func entityName(for cell: CubeCell) -> String {
            "cube-cell|\(cell.face.rawValue)|\(cell.x)|\(cell.y)"
        }

        private static func cell(from name: String) -> CubeCell? {
            let pieces = name.split(separator: "|")
            guard pieces.count == 4,
                  pieces[0] == "cube-cell",
                  let face = CubeFace(rawValue: String(pieces[1])),
                  let x = Int(pieces[2]),
                  let y = Int(pieces[3])
            else { return nil }
            return CubeCell(face: face, x: x, y: y)
        }
    }
}
