import 'package:flutter/material.dart';

import '../../../listings/domain/models/listing.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.category,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                listing.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                listing.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(listing.creator),
                  ),

                  Text(
                    '${listing.collaboratorsNeeded} colaboradores',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}