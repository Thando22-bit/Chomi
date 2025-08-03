import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ✅ Simple native ad style that looks like a post
class ListTileNativeAdFactory extends NativeAdFactory {
  @override
  Widget createNativeAd(NativeAd ad, {Key? key}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Ad headline
          Text(
            ad.headline ?? "Sponsored",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),

          // ✅ Ad body
          if (ad.body != null)
            Text(
              ad.body!,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),

          const SizedBox(height: 8),

          Row(
            children: [
              if (ad.icon != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image(
                    image: AdImage(ad.icon!).image,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 10),

              // ✅ Call-to-action button
              if (ad.callToAction != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {},
                  child: Text(ad.callToAction!),
                ),
            ],
          )
        ],
      ),
    );
  }
}

