/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import UIKit
import Foundation

internal class RUMDebugging {
    private let applicationScope: RUMApplicationScope
    private lazy var canvas: UIView = {
        let window = UIApplication.shared.keyWindow
        let view = RUMDebugView(frame: window?.bounds ?? .zero)
        window?.addSubview(view)
        return view
    }()

    init(applicationScope: RUMApplicationScope) {
        self.applicationScope = applicationScope
    }

    func update() {
        DispatchQueue.main.async {
            self.outlineRUMViews()
        }
    }

    private func outlineRUMViews() {
        canvas.subviews.forEach { $0.removeFromSuperview() }

        let viewScopes = applicationScope.sessionScope?.viewScopes ?? []
        var outlines: [UIView] = []
        var labels: [UIView] = []

        var nextOutlineBounds = canvas.bounds.inset(by: canvas.safeAreaInsets)
        var nextLabelBounds = canvas.bounds.inset(by: canvas.safeAreaInsets)

        let activeViewColor =  #colorLiteral(red: 0.4686954021, green: 0.2687242031, blue: 0.7103499174, alpha: 1)
        let inactiveViewColor =  #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        let alphas = (0..<viewScopes.count)
            .map { index in CGFloat(pow(0.75, Double(index + 1))) }
            .reversed()

        zip(viewScopes, alphas).forEach { scope, alpha in
            let outlineView = RUMViewOutline(color: scope.isActiveView ? activeViewColor : inactiveViewColor)
            outlineView.alpha = alpha
            let labelView = RUMViewLabel(name: scope.viewURI)
            labelView.alpha = alpha

            outlineView.frame = nextOutlineBounds
            labelView.frame = nextLabelBounds

            outlines.append(outlineView)
            labels.append(labelView)

            nextOutlineBounds = nextOutlineBounds.insetBy(
                dx: RUMViewOutline.Constants.lineWidth,
                dy: RUMViewOutline.Constants.lineWidth
            )
            nextLabelBounds = nextOutlineBounds
        }

        outlines.forEach {
            canvas.addSubview($0)
            $0.setNeedsDisplay()
        }
        labels.forEach { canvas.addSubview($0) }
    }
}

private class RUMViewOutline: RUMDebugView {
    struct Constants {
        static let lineWidth: CGFloat = 15
    }

    private let color: UIColor

    init(color: UIColor) {
        self.color = color
        super.init(frame: .zero)
    }

    override func draw(_ rect: CGRect) {
        let innerRect = rect.insetBy(dx: Constants.lineWidth * 0.5, dy: Constants.lineWidth * 0.5)
        let bpath = UIBezierPath(rect: innerRect)
        color.set()
        bpath.lineWidth = Constants.lineWidth
        bpath.stroke()
    }
}

private class RUMViewLabel: RUMDebugView {
    struct Constants {
        static let labelHeight: CGFloat = 15
    }

    private let label: UILabel

    init(name: String) {
        let label = UILabel(frame: .zero)
        label.text = name
        label.font = .monospacedDigitSystemFont(ofSize: Constants.labelHeight * 0.8, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.baselineAdjustment = .none

        self.label = label

        super.init(frame: .zero)

        self.addSubview(label)
    }

    override func layoutSubviews() {
        label.frame = .init(
            x: bounds.minX,
            y: bounds.maxY - Constants.labelHeight,
            width: bounds.width,
            height: Constants.labelHeight
        )
    }
}

private class RUMDebugView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
