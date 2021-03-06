context("getErrorMessages")

test_that("getErrorMessages", {
  reg = makeRegistry(file.dir = NA, make.default = FALSE)
  fun = function(i) if (i == 3) stop("foobar") else i
  ids = batchMap(fun, i = 1:5, reg = reg)
  submitAndWait(reg, 1:4)

  tab = getErrorMessages(ids, reg = reg)
  expect_data_table(tab, nrow = 5, ncol = 4, key = "job.id")
  expect_set_equal(names(tab), c("job.id", "terminated", "error", "message"))
  expect_identical(tab$job.id, 1:5)
  expect_equal(tab$terminated, c(rep(TRUE, 4), FALSE))
  expect_equal(tab$error, replace(logical(5), 3, TRUE))
  expect_character(tab$message)
  expect_equal(is.na(tab$message), !replace(logical(5), 3, TRUE))
  expect_string(tab$message[3], fixed = "foobar")

  tab = getErrorMessages(ids, missing.as.error = TRUE, reg = reg)
  expect_data_table(tab, nrow = 5, ncol = 4, key = "job.id")
  expect_set_equal(names(tab), c("job.id", "terminated", "error", "message"))
  expect_identical(tab$job.id, 1:5)
  expect_equal(tab$terminated, c(rep(TRUE, 4), FALSE))
  expect_equal(tab$error, replace(logical(5), c(3, 5), TRUE))
  expect_character(tab$message)
  expect_equal(is.na(tab$message), !replace(logical(5), c(3, 5), TRUE))
  expect_string(tab$message[3], fixed = "foobar")
  expect_string(tab$message[5], fixed = "[not terminated]")
})
