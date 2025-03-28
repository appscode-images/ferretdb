// Copyright 2021 FerretDB Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package middleware

import (
	"context"
	"log/slog"

	"github.com/FerretDB/wire"
)

// Observability is a middleware that will wrap the command handler with logs, traces, and metrics.
//
// TODO https://github.com/FerretDB/FerretDB/issues/4439
func Observability(next HandlerFunc, l *slog.Logger) HandlerFunc {
	return func(ctx context.Context, msg *wire.OpMsg) (*wire.OpMsg, error) {
		return next(ctx, msg)
	}
}
