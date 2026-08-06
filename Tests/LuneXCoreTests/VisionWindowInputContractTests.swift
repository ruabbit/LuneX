import XCTest

final class VisionWindowInputContractTests: XCTestCase {
    func testWindowedStateExposesEveryUnavailablePresentationFeature() throws {
        let state = try presentation()

        XCTAssertEqual(state.mode, .windowed)
        XCTAssertEqual(
            state.unavailableFeatures.map(\.feature),
            VisionUnavailablePresentationFeature.allCases.sorted()
        )
        XCTAssertEqual(
            Set(state.unavailableFeatures.map(\.reason)),
            [.stage18WindowedOnly]
        )
    }

    func testWindowedStateRejectsWrongPlatformMissingAndDuplicateFeatures() throws {
        XCTAssertThrowsError(try VisionWindowedPresentationState.windowedOnly(
            ownership: ownership(platform: .tvOS),
            revision: revision(),
            surfaceGeneration: generation(.surface, 1)
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .platformMismatch
            )
        }

        let states = VisionUnavailablePresentationFeature.allCases.map {
            VisionUnavailablePresentationState(
                feature: $0,
                reason: .runtimeUnavailable
            )
        }
        XCTAssertThrowsError(try VisionWindowedPresentationState(
            ownership: ownership(),
            revision: revision(),
            surfaceGeneration: generation(.surface, 1),
            unavailableFeatures: Array(states.dropLast())
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .invalidUnavailableFeatureSet
            )
        }
        XCTAssertThrowsError(try VisionWindowedPresentationState(
            ownership: ownership(),
            revision: revision(),
            surfaceGeneration: generation(.surface, 1),
            unavailableFeatures: states + [states[0]]
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .duplicateUnavailableFeature(states[0].feature)
            )
        }
    }

    func testWindowInputSnapshotRequiresMatchingRevisionAndGenerations() throws {
        let presentation = try presentation()
        let scene = try sceneSurface()
        let input = try inputCapabilities()
        XCTAssertNoThrow(try VisionWindowInputSnapshot(
            presentation: presentation,
            sceneSurface: scene,
            inputCapabilities: input
        ))

        XCTAssertThrowsError(try VisionWindowInputSnapshot(
            presentation: presentation,
            sceneSurface: sceneSurface(revision: revision(2)),
            inputCapabilities: input
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .revisionMismatch
            )
        }
        XCTAssertThrowsError(try VisionWindowInputSnapshot(
            presentation: presentation,
            sceneSurface: sceneSurface(
                surfaceGeneration: generation(.surface, 2)
            ),
            inputCapabilities: input
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .surfaceGenerationMismatch
            )
        }
        XCTAssertThrowsError(try VisionWindowInputSnapshot(
            presentation: presentation,
            sceneSurface: scene,
            inputCapabilities: inputCapabilities(
                inputGeneration: generation(.input, 2)
            )
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .inputGenerationMismatch
            )
        }
    }

    func testEligibleInputRequiresActiveVisibleAttachedSurface() throws {
        for scene in [
            try sceneSurface(activity: .inactive),
            try sceneSurface(isVisible: false)
        ] {
            XCTAssertThrowsError(try VisionWindowInputSnapshot(
                presentation: presentation(),
                sceneSurface: scene,
                inputCapabilities: inputCapabilities()
            )) { error in
                XCTAssertEqual(
                    error as? VisionWindowInputContractError,
                    .eligibleSurfaceRequired
                )
            }
        }
        XCTAssertThrowsError(try VisionWindowInputSnapshot(
            presentation: presentation(),
            sceneSurface: sceneSurface(
                attachment: .detached,
                isVisible: false
            ),
            inputCapabilities: inputCapabilities()
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .eligibleSurfaceRequired
            )
        }
    }

    func testEverySupportedVisionInputPathIsAdmitted() throws {
        let snapshot = try windowInputSnapshot()
        for path in VisionInputPath.allCases {
            let request = try admissionRequest(path: path)
            XCTAssertEqual(
                VisionInputAdmissionResolver.resolve(
                    request,
                    snapshot: snapshot
                ),
                .admit(
                    path: path,
                    inputGeneration: request.inputGeneration
                )
            )
        }
    }

    func testAdmissionRejectsUnavailableCapabilityAndFocus() throws {
        let keyboardOnly = try windowInputSnapshot(
            supported: [.keyboard]
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(path: .pointer),
                snapshot: keyboardOnly
            ),
            .unavailable(
                path: .pointer,
                reason: .capabilityUnavailable(.pointer)
            )
        )

        let unfocused = try windowInputSnapshot(
            focusEligibility: .ineligible(.notFocused)
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(path: .keyboard),
                snapshot: unfocused
            ),
            .unavailable(
                path: .keyboard,
                reason: .focusIneligible(.notFocused)
            )
        )
    }

    func testAdmissionRejectsEveryStaleGenerationSeparately() throws {
        let snapshot = try windowInputSnapshot()
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(
                    presentationGeneration: generation(.presentation, 2)
                ),
                snapshot: snapshot
            ),
            .unavailable(
                path: .keyboard,
                reason: .stalePresentationGeneration
            )
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(
                    surfaceGeneration: generation(.surface, 2)
                ),
                snapshot: snapshot
            ),
            .unavailable(
                path: .keyboard,
                reason: .staleSurfaceGeneration
            )
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(inputGeneration: generation(.input, 2)),
                snapshot: snapshot
            ),
            .unavailable(
                path: .keyboard,
                reason: .staleInputGeneration
            )
        )
    }

    func testAdmissionRejectsDetachedInactiveAndHiddenSurface() throws {
        let detached = try windowInputSnapshot(
            activity: .inactive,
            attachment: .detached,
            isVisible: false,
            focusEligibility: .ineligible(.detached)
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(),
                snapshot: detached
            ),
            .unavailable(path: .keyboard, reason: .surfaceDetached)
        )

        let inactive = try windowInputSnapshot(
            activity: .inactive,
            focusEligibility: .ineligible(.sceneInactive)
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(),
                snapshot: inactive
            ),
            .unavailable(path: .keyboard, reason: .sceneInactive)
        )

        let hidden = try windowInputSnapshot(
            isVisible: false,
            focusEligibility: .ineligible(.notFocused)
        )
        XCTAssertEqual(
            VisionInputAdmissionResolver.resolve(
                try admissionRequest(),
                snapshot: hidden
            ),
            .unavailable(path: .keyboard, reason: .surfaceHidden)
        )
    }

    func testSystemAndUnsupportedSpatialInteractionsStayLocal() {
        let reserved: Set<VisionSystemReservedInteraction> = [
            .systemGesture,
            .recenter,
            .capture,
            .safety,
            .volume,
            .escape
        ]
        for interaction in VisionSystemReservedInteraction.allCases {
            let expected: VisionSystemInteractionDisposition = reserved.contains(
                interaction
            ) ? .reserveLocally : .dropUnsupportedLocally
            XCTAssertEqual(
                VisionSystemInteractionDecision.resolve(interaction),
                VisionSystemInteractionDecision(
                    interaction: interaction,
                    disposition: expected
                )
            )
        }
    }

    func testFocusLossReleaseOrdersHandlersMonitorsBarrierAndNavigation() throws {
        let snapshot = try windowInputSnapshot()
        let state = VisionWindowInputOwnershipState(snapshot: snapshot)
        let lease0 = try controllerLease(slot: 0, lease: 1)
        let lease2 = try controllerLease(slot: 2, lease: 2)
        let request = try releaseRequest(
            scope: .focusLoss,
            controllerLeases: [lease2, lease0],
            monitoredPaths: [.pointer, .keyboard, .indirectPointer],
            restoreReason: .notFocused
        )
        let transition = try state.releasing(request)

        XCTAssertEqual(transition.state.phase, .released)
        XCTAssertEqual(transition.effects, [
            .closeAdmission(inputGeneration: request.inputGeneration),
            .removeControllerHandlers([lease0, lease2]),
            .cancelInputMonitors([.indirectPointer, .keyboard, .pointer]),
            .awaitHeldInputRelease(inputGeneration: request.inputGeneration),
            .restoreLocalNavigation(.notFocused)
        ])
    }

    func testTeardownCancelsObserversAndReleasesSurfaceAfterBarrier() throws {
        let state = VisionWindowInputOwnershipState(
            snapshot: try windowInputSnapshot()
        )
        let request = try releaseRequest(
            scope: .teardown,
            monitoredPaths: [.keyboard],
            restoreReason: nil
        )
        let transition = try state.releasing(request)

        XCTAssertEqual(transition.effects, [
            .closeAdmission(inputGeneration: request.inputGeneration),
            .cancelSystemInteractionObservers,
            .cancelInputMonitors([.keyboard]),
            .awaitHeldInputRelease(inputGeneration: request.inputGeneration),
            .releaseSurfaceLease(surfaceGeneration: request.surfaceGeneration)
        ])
    }

    func testRepeatedReleaseIsIdempotent() throws {
        let state = VisionWindowInputOwnershipState(
            snapshot: try windowInputSnapshot()
        )
        let request = try releaseRequest(
            scope: .teardown,
            restoreReason: .stopped
        )
        let first = try state.releasing(request)
        let second = try first.state.releasing(request)

        XCTAssertEqual(first.state.phase, .released)
        XCTAssertEqual(second.state, first.state)
        XCTAssertTrue(second.effects.isEmpty)
    }

    func testReleaseRequestRequiresFocusReasonAndMonitorPaths() throws {
        XCTAssertThrowsError(try releaseRequest(
            scope: .focusLoss,
            restoreReason: nil
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .restoreReasonRequired
            )
        }
        XCTAssertThrowsError(try releaseRequest(
            scope: .teardown,
            monitoredPaths: [.extendedGamepad]
        )) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .invalidMonitorPath(.extendedGamepad)
            )
        }
    }

    func testReleaseRejectsStaleOwnershipGenerations() throws {
        let state = VisionWindowInputOwnershipState(
            snapshot: try windowInputSnapshot()
        )
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            presentationGeneration: generation(.presentation, 2)
        ))) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .presentationGenerationMismatch
            )
        }
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            surfaceGeneration: generation(.surface, 2)
        ))) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .surfaceGenerationMismatch
            )
        }
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            inputGeneration: generation(.input, 2)
        ))) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .inputGenerationMismatch
            )
        }
    }

    func testReleaseRejectsControllerPlatformGenerationSlotAndLeaseErrors() throws {
        let state = VisionWindowInputOwnershipState(
            snapshot: try windowInputSnapshot()
        )
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            controllerLeases: [controllerLease(
                slot: 0,
                lease: 1,
                platform: .tvOS
            )]
        )))
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            controllerLeases: [controllerLease(
                slot: 0,
                lease: 1,
                inputGeneration: generation(.input, 2)
            )]
        )))

        let lease = try controllerLease(slot: 0, lease: 1)
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            controllerLeases: [lease, lease]
        ))) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .duplicateControllerSlot(0)
            )
        }
        let duplicateLease = try controllerLease(slot: 1, lease: 1)
        XCTAssertThrowsError(try state.releasing(releaseRequest(
            controllerLeases: [lease, duplicateLease]
        ))) { error in
            XCTAssertEqual(
                error as? VisionWindowInputContractError,
                .duplicateControllerLease(1)
            )
        }
    }

    func testRuntimeOwnershipAggregatesAreNotEncodable() {
        let runtimeTypes: [Any.Type] = [
            TVVisionPresentationOwnership.self,
            TVVisionPlatformPresentationSnapshot.self,
            TVRemoteCaptureState.self,
            TVRemoteCaptureEffect.self,
            VisionWindowInputSnapshot.self,
            VisionWindowInputOwnershipState.self,
            VisionInputReleaseEffect.self
        ]

        for type in runtimeTypes {
            XCTAssertFalse(
                type is any Encodable.Type,
                "Runtime ownership type \(type) must not become persistable"
            )
        }
    }

    func testOnlyBoundedRawPlatformEnumsCrossTheEncodingBoundary() throws {
        let rawTypes: [Any.Type] = [
            TVRemoteReservedCommand.self,
            TVRemoteReservedDisposition.self
        ]
        for type in rawTypes {
            XCTAssertTrue(type is any Encodable.Type)
        }

        let encoder = JSONEncoder()
        let payloads = [
            try encoder.encode(TVRemoteReservedCommand.allCases),
            try encoder.encode([
                TVRemoteReservedDisposition.showOverlayOrExitCapture,
                .deferToSystem,
                .ignoreLocally
            ])
        ]
        let forbiddenTerms = [
            "host",
            "endpoint",
            "uuid",
            "window",
            "scene",
            "controller",
            "gesture",
            "credential",
            "secret"
        ]

        for payload in payloads {
            XCTAssertLessThanOrEqual(payload.count, 512)
            let json = try XCTUnwrap(
                String(data: payload, encoding: .utf8)?.lowercased()
            )
            for term in forbiddenTerms {
                XCTAssertFalse(
                    json.contains(term),
                    "Encoded platform enum leaked forbidden term \(term)"
                )
            }
        }
    }

    private func ownership(
        platform: TVVisionPlatform = .visionOS,
        presentationGeneration: TVVisionGeneration? = nil,
        inputGeneration: TVVisionGeneration? = nil
    ) throws -> TVVisionPresentationOwnership {
        try TVVisionPresentationOwnership(
            platform: platform,
            sessionID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            mediaGeneration: 1,
            presentationGeneration: presentationGeneration
                ?? generation(.presentation, 1),
            inputGeneration: inputGeneration ?? generation(.input, 1)
        )
    }

    private func presentation(
        ownership: TVVisionPresentationOwnership? = nil,
        revision: TVVisionSemanticRevision? = nil,
        surfaceGeneration: TVVisionGeneration? = nil
    ) throws -> VisionWindowedPresentationState {
        try VisionWindowedPresentationState.windowedOnly(
            ownership: ownership ?? self.ownership(),
            revision: revision ?? self.revision(),
            surfaceGeneration: surfaceGeneration ?? generation(.surface, 1)
        )
    }

    private func sceneSurface(
        revision: TVVisionSemanticRevision? = nil,
        surfaceGeneration: TVVisionGeneration? = nil,
        activity: AppSceneActivity = .active,
        attachment: TVVisionSurfaceAttachment = .attached,
        isVisible: Bool = true
    ) throws -> TVVisionSceneSurfaceSnapshot {
        let surfaceGeneration = try surfaceGeneration ?? generation(.surface, 1)
        return try TVVisionSceneSurfaceSnapshot(
            platform: .visionOS,
            revision: revision ?? self.revision(),
            surfaceGeneration: surfaceGeneration,
            activity: activity,
            attachment: attachment,
            isVisible: isVisible,
            geometry: attachment == .attached
                ? surfaceGeometry(surfaceGeneration: surfaceGeneration)
                : nil
        )
    }

    private func surfaceGeometry(
        surfaceGeneration: TVVisionGeneration
    ) throws -> TVVisionSurfaceGeometry {
        try TVVisionSurfaceGeometry(
            platform: .visionOS,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(x: 0, y: 0, width: 800, height: 600),
            windowBounds: TVVisionRect(x: 0, y: 0, width: 800, height: 600),
            safeAreaInsets: .zero,
            scale: 2,
            drawableSize: PixelSize(width: 1_600, height: 1_200)
        )
    }

    private func inputCapabilities(
        revision: TVVisionSemanticRevision? = nil,
        inputGeneration: TVVisionGeneration? = nil,
        supported: Set<TVVisionInputCapability>? = nil,
        focusEligibility: TVVisionFocusEligibility = .eligible
    ) throws -> TVVisionInputCapabilitySnapshot {
        try TVVisionInputCapabilitySnapshot(
            platform: .visionOS,
            revision: revision ?? self.revision(),
            inputGeneration: inputGeneration ?? generation(.input, 1),
            supported: supported ?? Set(
                VisionInputPath.allCases.map(\.capability)
            ),
            focusEligibility: focusEligibility
        )
    }

    private func windowInputSnapshot(
        activity: AppSceneActivity = .active,
        attachment: TVVisionSurfaceAttachment = .attached,
        isVisible: Bool = true,
        supported: Set<TVVisionInputCapability>? = nil,
        focusEligibility: TVVisionFocusEligibility = .eligible
    ) throws -> VisionWindowInputSnapshot {
        try VisionWindowInputSnapshot(
            presentation: presentation(),
            sceneSurface: sceneSurface(
                activity: activity,
                attachment: attachment,
                isVisible: isVisible
            ),
            inputCapabilities: inputCapabilities(
                supported: supported,
                focusEligibility: focusEligibility
            )
        )
    }

    private func admissionRequest(
        presentationGeneration: TVVisionGeneration? = nil,
        surfaceGeneration: TVVisionGeneration? = nil,
        inputGeneration: TVVisionGeneration? = nil,
        path: VisionInputPath = .keyboard
    ) throws -> VisionInputAdmissionRequest {
        try VisionInputAdmissionRequest(
            presentationGeneration: presentationGeneration
                ?? generation(.presentation, 1),
            surfaceGeneration: surfaceGeneration ?? generation(.surface, 1),
            inputGeneration: inputGeneration ?? generation(.input, 1),
            path: path
        )
    }

    private func releaseRequest(
        presentationGeneration: TVVisionGeneration? = nil,
        surfaceGeneration: TVVisionGeneration? = nil,
        inputGeneration: TVVisionGeneration? = nil,
        scope: VisionInputReleaseScope = .teardown,
        controllerLeases: [TVVisionControllerLease] = [],
        monitoredPaths: Set<VisionInputPath> = [],
        restoreReason: TVVisionFocusIneligibilityReason? = nil
    ) throws -> VisionInputReleaseRequest {
        try VisionInputReleaseRequest(
            presentationGeneration: presentationGeneration
                ?? generation(.presentation, 1),
            surfaceGeneration: surfaceGeneration ?? generation(.surface, 1),
            inputGeneration: inputGeneration ?? generation(.input, 1),
            scope: scope,
            controllerLeases: controllerLeases,
            monitoredPaths: monitoredPaths,
            restoreReason: restoreReason
        )
    }

    private func controllerLease(
        slot: Int,
        lease: UInt64,
        platform: TVVisionPlatform = .visionOS,
        inputGeneration: TVVisionGeneration? = nil
    ) throws -> TVVisionControllerLease {
        try TVVisionControllerLease(
            platform: platform,
            leaseGeneration: generation(.controller, lease),
            inputGeneration: inputGeneration ?? generation(.input, 1),
            slot: TVVisionControllerSlot(slot),
            profile: .extendedGamepad,
            capabilities: [.rumble]
        )
    }

    private func generation(
        _ domain: TVVisionGenerationDomain,
        _ rawValue: UInt64
    ) throws -> TVVisionGeneration {
        try TVVisionGeneration(domain: domain, rawValue: rawValue)
    }

    private func revision(_ rawValue: UInt64 = 1) throws
        -> TVVisionSemanticRevision
    {
        try TVVisionSemanticRevision(rawValue: rawValue)
    }
}
