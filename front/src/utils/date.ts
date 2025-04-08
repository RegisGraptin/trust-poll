export function convertDate(time: string) {
  return new Date(Number(time) * 1000).toLocaleString(undefined, {
    dateStyle: "medium",
  });
}

export function dateToTimestamps(time: string) {
  return Math.round(new Date(time).getTime() / 1000);
}
