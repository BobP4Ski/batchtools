# @title Merge the computational status of two registries
#
# @description
# Merges the computational status of jobs found in the registries located at
# \code{file.dir} into the registry \code{reg}.
# Both registries must have the same jobs defined and may only differ w.r.t.
# the computational status of the jobs.
# This function is intended to be applied in the following context:
# \enumerate{
#   \item Define all jobs locally (and ensure they work as intended by testing them).
#   \item Copy the \code{file.dir} to remote systems.
#   \item Submit a subset of jobs on each system,
#   \item After all jobs are terminated, copy both registries back to the local file system. Remember to keep backups.
#   \item Load one registry with \code{\link{loadRegistry}}, merge the second with this function.
# }
#
# @param file.dir [\code{character(1)}]\cr
#   Path to first registry.
# @template reg
# @return [\code{\link{Registry}}].
# @export
# @examples
# target = makeRegistry(NA, make.default = FALSE)
# batchMap(identity, 1:10, reg = target)
# td = tempdir()
# file.copy(target$file.dir, td, recursive = TRUE)
# file.dir = file.path(td, basename(target$file.dir))
# source = loadRegistry(file.dir, update.paths = TRUE)
#
# submitJobs(1:5, reg = target)
# submitJobs(6:10, reg = source)
#
# new = mergeRegistries(source, target)
mergeRegistries = function(source, target = getDefaultRegistry()) {
  assertRegistry(source, sync = TRUE, writeable = TRUE, running.ok = FALSE)
  assertRegistry(target, sync = TRUE, writeable = TRUE, running.ok = FALSE)
  if (source$file.dir == target$file.dir)
    stop("You must provide two different registries (using different file directories")
  hash = function(x) unlist(.mapply(function(...) digest(list(...)), x[, !"def.id"], list()))

  # update only jobs which are not already computed and only those which are terminated
  status = source$status[.findNotDone(target), ][.findSubmitted(source)]

  # create a hash of parameters to match on
  status$hash = hash(sjoin(source$defs, status))

  # create temp table for target with the same hashes
  tmp = data.table(def.id = status$def.id, hash = hash(sjoin(target$defs, status)))

  # filter status to keep only jobs with matching ids and hashes
  # in status there are now only jobs which have an exact match in target$status
  # perform an updating join
  status = status[tmp, nomatch = 0L, on = c("def.id", "hash")]
  info("Merging %i jobs ...", nrow(status))

  info("Copying results ...")
  file.copy(
    from = file.path(source$file.dir, "results", sprintf("%i.rds", status$job.id)),
    to = file.path(target$file.dir, "results", sprintf("%i.rds", status$job.id))
  )

  info("Copying logs ...")
  file.copy(
    from = file.path(source$file.dir, "logs", sprintf("%s.log", status$job.hash)),
    to = file.path(target$file.dir, "results", sprintf("%s.log", status$job.hash))
  )

  ext.dirs = intersect(list.files(file.path(source$file.dir, "external")), as.character(status$job.id))
  if (length(ext.dirs) > 0L) {
    info("Copying external directories ...")
    target.dirs = file.path(target$file.dir, "external", ext.dirs)
    lapply(target.dirs[!dir.exists(target.dirs)], dir.create)
    file.copy(
      from = file.path(source$file.dir, "external", ext.dirs),
      to = dirname(target.dirs),
      recursive = TRUE
    )
  }

  target$status = ujoin(target$status, status, by = "job.id")
  saveRegistry(target)
}
