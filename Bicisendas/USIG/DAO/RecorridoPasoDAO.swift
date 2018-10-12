//
//  RecorridoPasoDAO.swift
//  Bicisendas
//
//  Created by Pablo Bendersky on 12/10/2018.
//  Copyright © 2018 Pablo Bendersky. All rights reserved.
//

import XMLParsing

public struct RecorridoPasoDAO: Codable {

    private let gml: String

    public let time: Int?
    public let type: String
    public let distance: Int?
    public let gmlFeature: GMLFeature?

    enum CodingKeys: String, CodingKey {
        case gml
        case time
        case type
        case distance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.gml = try container.decode(String.self, forKey: .gml)
        self.time = try? container.decode(Int.self, forKey: .time)
        self.type = try container.decode(String.self, forKey: .type)
        self.distance = try? container.decode(Int.self, forKey: .distance)

        let data = self.gml.data(using: .utf8)!

        self.gmlFeature = try XMLDecoder().decode(GMLFeature.self, from: data)
    }
}
