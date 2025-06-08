//
//  ImageCache.swift
//  MovieListApp
//
//  Created by Manasi Sawant on 3/15/25.
//
import UIKit

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    func getImage(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
