test_that("int64_overflows flags only true overflows", {
  x <- c("0", "-1", "123",
         "9223372036854775807",     # max int64, fits
         "9223372036854775808",     # max int64 + 1, overflows
         "18446744073709551615",    # max uint64, overflows
         NA_character_)
  # NA input is not an overflow
  expect_identical(int64_overflows(x),
                   c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE))
})

test_that("rids2raw round-trips through readBin", {
  ids <- c("123", "456", "9223372036854775807")
  raw <- rids2raw(ids)
  expect_type(raw, "raw")
  expect_length(raw, 8L * length(ids))
  back <- readBin(raw, what = "double", n = length(ids), size = 8L,
                  endian = "little")
  class(back) <- "integer64"
  expect_identical(as.character(back), ids)
})

test_that("rids2raw honours endianness", {
  expect_false(identical(rids2raw(1:3, endian = "little"),
                         rids2raw(1:3, endian = "big")))
})
