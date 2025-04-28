extract_json_tags <- function(text) {
  # Find position of "final"
  final_pos <- regexpr("final", text)
  
  if (final_pos == -1) return(NA_character_)  # "final" not found
  
  # Split text into before and after "final"
  before_final <- substr(text, 1, final_pos - 1)
  after_final <- substr(text, final_pos + attr(final_pos, "match.length"), nchar(text))
  
  # Try extracting JSON tags after "final"
  after_matches <- stringr::str_extract_all(after_final, "\\{[^{}]*\\}")[[1]]
  
  if (length(after_matches) > 0) {
    return(paste(after_matches, collapse = ",,,,,"))
  }
  
  # If none found after, try extracting before "final"
  before_matches <- stringr::str_extract_all(before_final, "\\{[^{}]*\\}")[[1]]
  
  if (length(before_matches) > 0) {
    return(paste(before_matches, collapse = ",,,,,"))
  }
  
  # No matches found at all
  return(NA_character_)
}




pair_coloc_test <- function(type_A, type_B, data, k = 15) {
  A <- data$category == type_A
  B <- data$category == type_B
  nb <- st_knn(st_geometry(data), k = k)
  
  pairwise_colocation(A, B, nb, nsim = 999)
} 